# Uploads the data package to an existing Zenodo draft record through the
# REST API, resumably and with a bandwidth cap. Used for record 22879546
# (DOI 10.5281/zenodo.22879546) on 21 Sep 2026; the benchmark archive
# 10.5281/zenodo.22228405 was uploaded the same way on 1 Sep 2026.
#
#   powershell -ExecutionPolicy Bypass -File ops\zenodo\upload_zenodo.ps1 [-RecordId 22879546]
#       [-PackageDir <dir>] [-LimitRate 1200k] [-Only file,file] [-SetMetadata [-MetadataOnly]] [-Status]
#
# Token: a personal access token (scopes deposit:write, deposit:actions) in
#   %USERPROFILE%\.zenodo\token and, as a curl config line
#   `header = "Authorization: Bearer <token>"`, in %USERPROFILE%\.zenodo\curl.cfg
#   (curl -K keeps the token out of the process command line and of the log).
#   Revoke the token at https://zenodo.org/account/settings/applications/ after publishing.
#
# Behaviour
#   * every file is registered, PUT (curl --limit-rate <LimitRate>), committed,
#     and verified by comparing the server MD5 with the local one; a file that
#     is already complete and verified on the server is skipped, so the script
#     can be re-run after any interruption and continues where it stopped;
#   * network errors, Zenodo 5xx responses and stalls (< 512 B/s for 5 min)
#     are retried with a growing pause (30 s ... 10 min), up to -MaxAttempts
#     per file; a failed PUT only costs that one file (the archives are split
#     into 1 GiB parts by build_package.ps1 for exactly this reason);
#   * between files the script honours two control files in the package dir:
#     `ratelimit.txt` (a curl rate such as 800k or 2m; read before every PUT,
#     so the cap can be changed without restarting) and `pause.txt` (while it
#     exists, the script waits before starting the next file);
#   * everything is logged with time stamps to <PackageDir>\upload.log;
#   * -SetMetadata writes the record metadata (title, description, creators,
#     keywords, licence, related identifiers) through the legacy deposit API;
#     -Status only prints the server-side file list against the local package.
# Publishing is done by hand in the browser (https://zenodo.org/uploads/<id>).
param(
    [string]$RecordId = '22879546',
    [string]$PackageDir = (Join-Path (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))) 'zenodo_package_neutrino'),
    [string]$TokenDir = (Join-Path $env:USERPROFILE '.zenodo'),
    [string]$LimitRate = '1200k',
    [string[]]$Only = @(),
    [switch]$SetMetadata,
    [switch]$MetadataOnly,
    [switch]$Status,
    [int]$MaxAttempts = 60
)
$ErrorActionPreference = 'Continue'
$Z = $PackageDir
$CFG = Join-Path $TokenDir 'curl.cfg'
if (-not (Test-Path $CFG)) { throw "curl config with the token not found: $CFG (see the header of this script)" }
$API = "https://zenodo.org/api/records/$RecordId/draft/files"
$LOG = Join-Path $Z 'upload.log'
$TMP = Join-Path $Z '_tmp'
New-Item -ItemType Directory -Force -Path $TMP | Out-Null

function Log([string]$msg) {
    $line = "{0}  {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg
    Write-Host $line
    [System.IO.File]::AppendAllText($LOG, $line + "`r`n", [System.Text.UTF8Encoding]::new($false))
}

# --- small JSON calls through curl (auth from the config file) -------------
function Api([string]$method, [string]$url, [string]$bodyFile = '') {
    $out = Join-Path $TMP ('resp_' + [guid]::NewGuid().ToString('N') + '.json')
    $err = Join-Path $TMP 'curl_err.txt'
    $args = @('-sS', '-K', $CFG, '-X', $method, '--connect-timeout', '60', '--max-time', '300', '-o', $out, '-w', '%{http_code}')
    if ($bodyFile) { $args += @('-H', 'Content-Type: application/json', '--data-binary', "@$bodyFile") }
    $args += $url
    $code = & curl.exe @args 2>$err
    $exit = $LASTEXITCODE
    $body = if (Test-Path $out) { [System.IO.File]::ReadAllText($out) } else { '' }
    Remove-Item $out -ErrorAction SilentlyContinue
    $errtxt = if (Test-Path $err) { (Get-Content $err -Raw -ErrorAction SilentlyContinue) } else { '' }
    return @{ exit = $exit; code = [string]$code; body = $body; err = ("$errtxt").Trim() }
}
function Api-Retry([string]$method, [string]$url, [string]$bodyFile = '', [int]$tries = 12) {
    for ($i = 1; $i -le $tries; $i++) {
        $r = Api $method $url $bodyFile
        if ($r.exit -eq 0 -and $r.code -match '^2\d\d$') { return $r }
        $why = if ($r.exit -ne 0) { "curl exit $($r.exit): $($r.err)" } else { "HTTP $($r.code): " + $r.body.Substring(0, [Math]::Min(200, $r.body.Length)).Replace("`n", ' ') }
        if ($r.code -match '^4\d\d$' -and $r.code -ne '429') { Log "  $method $url -> $why (not retried)"; return $r }
        $wait = [Math]::Min(600, 30 * [Math]::Pow(2, [Math]::Min($i - 1, 4)))
        Log "  $method $url -> $why; retry $i/$tries in $wait s"
        Start-Sleep -Seconds $wait
    }
    return $r
}
function Get-Entries() {
    $r = Api-Retry 'GET' $API
    if ($r.exit -ne 0 -or $r.code -ne '200') { return $null }
    try { return (($r.body | ConvertFrom-Json).entries) } catch { Log "  file list not parseable: $($r.body.Substring(0, [Math]::Min(120, $r.body.Length)))"; return $null }
}

# --- the files of the package, small first -----------------------------------
$parts = @(Get-ChildItem $Z -Filter 'molewhacker-newtrinos-ablation.tar.part-*' | Sort-Object Name | Select-Object -ExpandProperty Name)
$files = @('DATA-README.md', 'SHA256SUMS.txt', 'molewhacker-newtrinos-logs.tar', 'molewhacker-newtrinos-extension.tar', 'molewhacker-newtrinos-runs.tar') + $parts
if ($Only.Count -gt 0) { $files = @($files | Where-Object { $Only -contains $_ }) }
foreach ($f in $files) { if (-not (Test-Path (Join-Path $Z $f))) { throw "missing $f in $Z (run build_package.ps1 first)" } }

$md5cache = @{}
function Local-MD5([string]$f) {
    if (-not $md5cache.ContainsKey($f)) { $md5cache[$f] = (Get-FileHash (Join-Path $Z $f) -Algorithm MD5).Hash.ToLower() }
    return $md5cache[$f]
}

# --- status only --------------------------------------------------------------
if ($Status) {
    $entries = Get-Entries
    $tot = 0L
    foreach ($f in $files) {
        $e = $entries | Where-Object { $_.key -eq $f }
        $sz = (Get-Item (Join-Path $Z $f)).Length
        if ($e -and $e.status -eq 'completed') { $ok = (($e.checksum -replace '^md5:', '') -eq (Local-MD5 $f)); $tot += $sz; "{0,-48} {1,9:N1} MB  completed  md5 {2}" -f $f, ($sz / 1MB), $(if ($ok) { 'OK' } else { 'MISMATCH' }) }
        elseif ($e) { "{0,-48} {1,9:N1} MB  {2}" -f $f, ($sz / 1MB), $e.status }
        else { "{0,-48} {1,9:N1} MB  -" -f $f, ($sz / 1MB) }
    }
    $all = ($files | ForEach-Object { (Get-Item (Join-Path $Z $_)).Length } | Measure-Object -Sum).Sum
    "on server and verified: {0:N2} of {1:N2} GB" -f ($tot / 1GB), ($all / 1GB)
    exit 0
}

# --- metadata (legacy deposit API; fields not listed here are left as set) ---
if ($SetMetadata) {
    $desc = @"
<p>Raw per-cell outputs of the neutrino-oscillation application reported in Chapter 9 and Appendix B of the master's thesis <i>Importance Sampling Methods in the Bayesian Analysis Toolkit</i> (Valentin Reindel, Technical University of Munich, Department of Physics, 2026): the joint three-flavor fit of Daya Bay, KamLAND and MINOS (11 parameters, both mass orderings) sampled by MoleWhacker, Metropolis-Hastings, NUTS, nested sampling and plain importance sampling under a common likelihood-evaluation budget; the ablation of MoleWhacker's iteration cap; and the extension by the IceCube DeepCore atmospheric sample (24 parameters, normal ordering). Likelihoods: Newtrinos.jl (P. Eller et al.), pinned commit fa87689d.</p>
<p>Companion code repository (pipeline, figures, tables, pinned environment): <a href="https://github.com/valeagent/molewhacker-newtrinos">github.com/valeagent/molewhacker-newtrinos</a>. Benchmark of the same sampler on synthetic targets: <a href="https://github.com/valeagent/molewhacker-bench">github.com/valeagent/molewhacker-bench</a>, data <a href="https://doi.org/10.5281/zenodo.22228405">10.5281/zenodo.22228405</a>.</p>
<p><b>Contents</b> (7.7 GB; every cell holds <code>result.h5</code> with samples, weights, log-densities and diagnostics, for MoleWhacker the iteration log and the stored final mixture, plus <code>metadata.json</code> and <code>summary.json</code>):</p>
<ul>
<li><code>molewhacker-newtrinos-runs.tar</code> (755 MB): the 74 cells of the three-experiment campaign (50 protocol cells: five samplers at 5e4 and 5e5 evaluations, seeds 11/23/41, both orderings, nested sampling to evidence convergence; 24 single-experiment and pairwise MoleWhacker cells of the subset study) &rarr; <code>out/runs/</code></li>
<li><code>molewhacker-newtrinos-ablation.tar.part-00</code> ... <code>part-06</code> (6.5 GB, seven parts of at most 1 GiB; concatenate in name order): the six MoleWhacker cells with the iteration cap lifted, with the complete per-iteration population and mixture history &rarr; <code>out_ablation/runs/</code></li>
<li><code>molewhacker-newtrinos-extension.tar</code> (249 MB): the DeepCore extension (protocol MoleWhacker cell with 30 seeds, two MH chains of 2.5e5 steps, MoleWhacker with n_seed = 8 for seeds 11/23/41, the fresh draws from every stored d = 24 mixture, and the metadata of the cells stopped or lost to the out-of-memory event of 15 Sep 2026) &rarr; <code>out_extension/</code>, <code>out_extension_nseed8/</code></li>
<li><code>molewhacker-newtrinos-logs.tar</code> (26 MB): stdout/stderr of every lane of the campaign &rarr; <code>out/logs/</code></li>
<li><code>DATA-README.md</code>, <code>SHA256SUMS.txt</code>: description, reassembly and unpacking instructions, checksums of the archives, the parts and the reassembled ablation archive.</li>
</ul>
<p><b>Usage.</b> Clone the companion repository, reassemble the ablation archive (<code>cat molewhacker-newtrinos-ablation.tar.part-* &gt; molewhacker-newtrinos-ablation.tar</code>; on Windows <code>copy /b</code>), verify with <code>sha256sum -c SHA256SUMS.txt --ignore-missing</code>, and unpack every archive at the repository root; every table and figure of the chapter then regenerates without re-running a cell (<code>README.md</code> of the repository lists the scripts in order). The runs are also regenerable from the queue files with seed-fixed random streams.</p>
<p>Data: CC-BY-4.0. Code (companion repository): MIT. The experimental data contained in the Newtrinos.jl likelihoods belong to the respective collaborations.</p>
"@
    $meta = @{ metadata = @{
        title            = 'molewhacker-newtrinos: raw run data of the MoleWhacker neutrino-oscillation application (thesis data)'
        upload_type      = 'dataset'
        publication_date = '2026-09-21'
        description      = $desc
        creators         = @(@{ name = 'Reindel, Valentin'; affiliation = 'Technical University of Munich, Department of Physics' })
        keywords         = @('Bayesian inference', 'importance sampling', 'adaptive importance sampling', 'Monte Carlo methods', 'sampling algorithms', 'neutrino oscillations', 'MoleWhacker', 'BAT.jl', 'Newtrinos.jl', 'Julia', 'Daya Bay', 'KamLAND', 'MINOS', 'IceCube DeepCore')
        license          = 'cc-by-4.0'
        access_right     = 'open'
        version          = '1.0.0'
        language         = 'eng'
        related_identifiers = @(
            @{ relation = 'isSupplementTo'; identifier = 'https://github.com/valeagent/molewhacker-newtrinos'; resource_type = 'software' },
            @{ relation = 'references';     identifier = '10.5281/zenodo.22228405';                            resource_type = 'dataset' }
        )
    } }
    $metaPath = Join-Path $TMP 'zmeta.json'
    [System.IO.File]::WriteAllText($metaPath, ($meta | ConvertTo-Json -Depth 6), [System.Text.UTF8Encoding]::new($false))
    $r = Api-Retry 'PUT' "https://zenodo.org/api/deposit/depositions/$RecordId" $metaPath
    if ($r.exit -eq 0 -and $r.code -match '^2\d\d$') {
        $d = $r.body | ConvertFrom-Json
        Log "metadata set: title=[$($d.metadata.title)] type=$($d.metadata.upload_type) license=$($d.metadata.license) doi=$($d.metadata.prereserve_doi.doi) creators=$($d.metadata.creators.Count) keywords=$($d.metadata.keywords.Count) related=$($d.metadata.related_identifiers.Count)"
    } else {
        Log "METADATA FAILED: HTTP $($r.code) $($r.err) $($r.body.Substring(0, [Math]::Min(400, $r.body.Length)))"
    }
}
if ($MetadataOnly) { exit 0 }

# --- upload loop --------------------------------------------------------------
function Current-Rate() {
    $p = Join-Path $Z 'ratelimit.txt'
    if (Test-Path $p) { $v = (Get-Content $p -Raw).Trim(); if ($v) { return $v } }
    return $LimitRate
}
function Wait-IfPaused() {
    $p = Join-Path $Z 'pause.txt'
    if (Test-Path $p) { Log "pause.txt present: waiting before the next file (delete the file to continue)"; while (Test-Path $p) { Start-Sleep -Seconds 30 }; Log "resumed" }
}
function Ensure-Uploaded([string]$f) {
    $path = Join-Path $Z $f
    $size = (Get-Item $path).Length
    $local = Local-MD5 $f
    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        $entries = Get-Entries
        if ($null -eq $entries) { Log "  file list unavailable; waiting 120 s"; Start-Sleep -Seconds 120; continue }
        $e = $entries | Where-Object { $_.key -eq $f }
        if ($e -and $e.status -eq 'completed') {
            if (($e.checksum -replace '^md5:', '') -eq $local) { Log "ok     $f ($([Math]::Round($size / 1MB, 1)) MB) verified md5 $local"; return $true }
            Log "  $f is complete on the server with a different MD5 ($($e.checksum)); deleting and re-uploading"
            $null = Api-Retry 'DELETE' "$API/$f"
            continue
        }
        if (-not $e) {
            $reg = Join-Path $TMP 'register.json'
            [System.IO.File]::WriteAllText($reg, "[{`"key`": `"$f`"}]", [System.Text.UTF8Encoding]::new($false))
            $r = Api-Retry 'POST' $API $reg
            if (-not ($r.exit -eq 0 -and $r.code -match '^2\d\d$')) { Log "  register $f failed (HTTP $($r.code)); waiting 120 s"; Start-Sleep -Seconds 120; continue }
        }
        Wait-IfPaused
        $rate = Current-Rate
        Log "put    $f ($([Math]::Round($size / 1MB, 1)) MB) attempt $attempt, rate cap $rate"
        $err = Join-Path $TMP 'put_err.txt'
        $out = Join-Path $TMP 'put_resp.json'
        $args = @('-sS', '-K', $CFG, '-X', 'PUT', '-H', 'Content-Type: application/octet-stream', '--upload-file', $path, '--connect-timeout', '60', '--speed-time', '300', '--speed-limit', '512', '-o', $out, '-w', '%{http_code} %{speed_upload} %{time_total} %{size_upload}')
        if ($rate) { $args += @('--limit-rate', $rate) }
        $args += "$API/$f/content"
        $t0 = Get-Date
        $w = & curl.exe @args 2>$err
        $exit = $LASTEXITCODE
        $errtxt = if (Test-Path $err) { ("" + (Get-Content $err -Raw -ErrorAction SilentlyContinue)).Trim() } else { '' }
        $parts = ("$w" -split '\s+')
        $code = $parts[0]; $spd = if ($parts.Count -gt 1) { [double]$parts[1] } else { 0 }; $sec = if ($parts.Count -gt 2) { [double]$parts[2] } else { 0 }; $sent = if ($parts.Count -gt 3) { [double]$parts[3] } else { 0 }
        if ($exit -ne 0 -or $code -notmatch '^2\d\d$') {
            $wait = [Math]::Min(600, 30 * [Math]::Pow(2, [Math]::Min($attempt - 1, 4)))
            Log "  put $f FAILED after $([Math]::Round($sec)) s ($([Math]::Round($sent / 1MB, 1)) MB sent): curl exit $exit, HTTP $code $errtxt; retry in $wait s"
            Start-Sleep -Seconds $wait
            continue
        }
        Log "  put $f done in $([Math]::Round($sec / 60, 1)) min at $([Math]::Round($spd / 1MB, 2)) MB/s; committing"
        $r = Api-Retry 'POST' "$API/$f/commit"
        if (-not ($r.exit -eq 0 -and $r.code -match '^2\d\d$')) { Log "  commit $f failed (HTTP $($r.code)); re-checking in 60 s"; Start-Sleep -Seconds 60; continue }
        # the next loop iteration re-reads the entry and verifies the MD5
    }
    Log "GIVING UP on $f after $MaxAttempts attempts"
    return $false
}

Log "=== upload to record $RecordId from $Z; $($files.Count) files; default rate cap $LimitRate ==="
$failed = @()
foreach ($f in $files) { if (-not (Ensure-Uploaded $f)) { $failed += $f } }

# --- final verification -------------------------------------------------------
$entries = Get-Entries
$bad = @()
$tot = 0L
foreach ($f in $files) {
    $e = $entries | Where-Object { $_.key -eq $f }
    $ok = $e -and $e.status -eq 'completed' -and (($e.checksum -replace '^md5:', '') -eq (Local-MD5 $f))
    if ($ok) { $tot += $e.size } else { $bad += $f }
}
if ($bad.Count -eq 0 -and $failed.Count -eq 0) {
    Log "UPLOAD-COMPLETE: all $($files.Count) files on the server and verified ($([Math]::Round($tot / 1GB, 2)) GB). Review https://zenodo.org/uploads/$RecordId and press Publish."
} else {
    Log "UPLOAD-INCOMPLETE: not verified: $($bad -join ', ') (re-run the script to continue)"
}
