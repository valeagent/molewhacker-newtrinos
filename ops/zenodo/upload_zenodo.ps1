# Uploads the data package to Zenodo through the REST API (same procedure as
# for the benchmark archive 10.5281/zenodo.22228405 on 1 Sep 2026).
#
#   1. Create a personal access token at https://zenodo.org/account/settings/applications/
#      with the scopes deposit:write and deposit:actions, then in this shell:
#          $env:ZENODO_TOKEN = '<token>'
#   2. Run
#          powershell -ExecutionPolicy Bypass -File ops\zenodo\upload_zenodo.ps1 [-PackageDir <dir>]
#      The script creates a new draft record, sets the metadata, uploads every
#      file of the package (one at a time; the 2 GiB parts take ~10 min each),
#      verifies the server-side MD5 of every file against the local one, and
#      prints the reserved DOI. Nothing is published: check the draft in the
#      browser (https://zenodo.org/me/uploads) and press Publish there.
#   3. Put the DOI into the thesis (preamble/macros.tex, \nuzenododoi), the
#      repository README.md and docs/ZENODO.md, and CITATION.cff.
#
# Re-running with -RecordId <id> resumes into an existing draft (files that
# are already complete on the server are skipped).
param([string]$RecordId = '')
$ErrorActionPreference = 'Stop'
$Z = $PSScriptRoot
if (-not $env:ZENODO_TOKEN) { throw 'set $env:ZENODO_TOKEN first (see the header of this script)' }
$H = @{ Authorization = "Bearer $env:ZENODO_TOKEN" }
$api = 'https://zenodo.org/api'

$files = @('DATA-README.md', 'SHA256SUMS.txt', 'molewhacker-newtrinos-runs.tar', 'molewhacker-newtrinos-extension.tar', 'molewhacker-newtrinos-logs.tar') + @(Get-ChildItem $Z -Filter 'molewhacker-newtrinos-ablation.tar.part-*' | Sort-Object Name | Select-Object -ExpandProperty Name)
foreach ($f in $files) { if (-not (Test-Path (Join-Path $Z $f))) { throw "missing $f (run build_package.ps1 first)" } }

$meta = @{
    metadata = @{
        title            = 'molewhacker-newtrinos: raw run data of the MoleWhacker neutrino-oscillation application (thesis data)'
        upload_type      = 'dataset'
        description      = (Get-Content (Join-Path $Z 'DATA-README.md') -Raw)
        creators         = @(@{ name = 'Reindel, Valentin'; affiliation = 'Technical University of Munich, Department of Physics' })
        keywords         = @('importance sampling', 'Bayesian inference', 'neutrino oscillations', 'MoleWhacker', 'BAT.jl', 'Newtrinos.jl', 'sampler benchmark', 'Daya Bay', 'KamLAND', 'MINOS', 'IceCube DeepCore')
        license          = 'cc-by-4.0'
        access_right     = 'open'
        version          = '1.0.0'
        language         = 'eng'
        related_identifiers = @(
            @{ relation = 'isSupplementTo'; identifier = 'https://github.com/valeagent/molewhacker-newtrinos'; resource_type = 'software' },
            @{ relation = 'isReferencedBy'; identifier = 'https://github.com/valeagent/molewhacker-bench'; resource_type = 'software' },
            @{ relation = 'references';     identifier = '10.5281/zenodo.22228405'; resource_type = 'dataset' }
        )
    }
}
$metaPath = Join-Path $Z '_zmeta.json'
[System.IO.File]::WriteAllText($metaPath, ($meta | ConvertTo-Json -Depth 6), [System.Text.UTF8Encoding]::new($false))

if ($RecordId) {
    "resuming draft $RecordId"
    $dep = Invoke-RestMethod -Headers $H -Uri "$api/deposit/depositions/$RecordId"
} else {
    $dep = Invoke-RestMethod -Headers $H -Method Post -ContentType 'application/json' -Body '{}' -Uri "$api/deposit/depositions"
    $RecordId = $dep.id
    "created draft $RecordId"
}
$null = Invoke-RestMethod -Headers $H -Method Put -ContentType 'application/json' -InFile $metaPath -Uri "$api/deposit/depositions/$RecordId"
"metadata set; reserved DOI: $($dep.metadata.prereserve_doi.doi)"

# files already on the server
$have = @{}
try { (Invoke-RestMethod -Headers $H -Uri "$api/records/$RecordId/draft/files").entries | ForEach-Object { $have[$_.key] = $_ } } catch { }

foreach ($f in $files) {
    $path = Join-Path $Z $f
    if ($have[$f] -and $have[$f].status -eq 'completed') { "skip   $f (already complete)"; continue }
    $sz = (Get-Item $path).Length
    "upload $f ({0:N1} MB)" -f ($sz / 1MB)
    # register the file, then PUT its content, then commit (Zenodo files API)
    $init = "[{`"key`": `"$f`"}]"
    $null = curl.exe -sS --fail -X POST -H "Authorization: Bearer $env:ZENODO_TOKEN" -H "Content-Type: application/json" --data-binary $init "$api/records/$RecordId/draft/files"
    curl.exe -sS --fail -X PUT -H "Authorization: Bearer $env:ZENODO_TOKEN" -H "Content-Type: application/octet-stream" --upload-file $path "$api/records/$RecordId/draft/files/$f/content" -o "$Z\_resp_$f.json"
    if ($LASTEXITCODE -ne 0) { throw "upload of $f failed (curl exit $LASTEXITCODE); re-run with -RecordId $RecordId to resume" }
    $null = curl.exe -sS --fail -X POST -H "Authorization: Bearer $env:ZENODO_TOKEN" "$api/records/$RecordId/draft/files/$f/commit"
}

"verifying server-side checksums"
$entries = (Invoke-RestMethod -Headers $H -Uri "$api/records/$RecordId/draft/files").entries
$bad = 0
foreach ($f in $files) {
    $e = $entries | Where-Object { $_.key -eq $f }
    $local = (Get-FileHash (Join-Path $Z $f) -Algorithm MD5).Hash.ToLower()
    $srv = ($e.checksum -replace '^md5:', '')
    if ($e.status -eq 'completed' -and $srv -eq $local) { "ok     $f" } else { $bad++; "BAD    $f status=$($e.status) server=$srv local=$local" }
}
if ($bad) { throw "$bad file(s) did not verify; re-run with -RecordId $RecordId" }
$dep = Invoke-RestMethod -Headers $H -Uri "$api/deposit/depositions/$RecordId"
""
"all files verified. Draft: https://zenodo.org/uploads/$RecordId"
"DOI (reserved, active after Publish): $($dep.metadata.prereserve_doi.doi)"
"next: review the draft in the browser and press Publish; then insert the DOI (thesis \nuzenododoi, README.md, docs/ZENODO.md, CITATION.cff)."
