# Builds the Zenodo data package of the neutrino application: plain tar
# archives of the raw per-cell run output (the files .gitignore excludes),
# the large archive split into parts, plus SHA256SUMS.txt and the
# DATA-README.md of this directory.
#
#   powershell -ExecutionPolicy Bypass -File ops\zenodo\build_package.ps1 [-PackageDir <dir>] [-SkipTar]
#       [-PartSize <bytes>] [-LargeParts <n>] [-SmallPartSize <bytes>]
#
# Part layout: the first -LargeParts parts have -PartSize, every further part
# -SmallPartSize (0 = all parts of -PartSize). The defaults reproduce the
# layout of record 10.5281/zenodo.22879546: two 1 GiB parts followed by
# 256 MiB parts. (The benchmark archive 10.5281/zenodo.22228405 uses 2 GiB
# parts throughout; on 21 Sep 2026 Zenodo's gateway cut 1 GiB transfers with
# HTTP 502 every few minutes, so the remainder went up in 256 MiB pieces that
# survive between two cuts. Concatenation in name order restores the archive
# whatever the part sizes.)
#
# PackageDir defaults to a sibling of the repository so that the 7.9 GB never
# enter git; -SkipTar re-splits and re-checksums existing archives. Takes a few
# minutes (I/O bound).
param(
    [string]$PackageDir = (Join-Path (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))) 'zenodo_package_neutrino'),
    [switch]$SkipTar,
    [long]$PartSize = 1GB,
    [int]$LargeParts = 2,
    [long]$SmallPartSize = 256MB
)
$ErrorActionPreference = 'Stop'
$REPO = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)   # ops/zenodo -> repository root
$Z = $PackageDir
$PART = [long]$PartSize
$SMALL = [long]$SmallPartSize
if ($PART -lt 64MB) { throw "PartSize must be at least 64 MiB (got $PART)" }
if ($SMALL -ne 0 -and $SMALL -lt 64MB) { throw "SmallPartSize must be 0 or at least 64 MiB (got $SMALL)" }
New-Item -ItemType Directory -Force -Path $Z | Out-Null

function Make-Tar([string]$name, [string[]]$paths) {
    $out = Join-Path $Z $name
    if (Test-Path $out) { Remove-Item $out -Force }
    & tar.exe -cf $out -C $REPO @paths
    if ($LASTEXITCODE -ne 0) { throw "tar failed for $name" }
    "{0,-42} {1,9:N1} MB" -f $name, ((Get-Item $out).Length / 1MB)
}

function Split-Archive([string]$name) {
    $f = Get-Item (Join-Path $Z $name)
    Get-ChildItem $Z -Filter "$name.part-*" | Remove-Item -Force
    if ($f.Length -le $PART) { return @() }
    $in = [System.IO.File]::OpenRead($f.FullName)
    $buf = New-Object byte[] (64MB); $i = 0; $parts = @()
    try {
        while ($in.Position -lt $in.Length) {
            $target = if ($SMALL -gt 0 -and $i -ge $LargeParts) { $SMALL } else { $PART }
            $pname = '{0}.part-{1:d2}' -f $name, $i
            $outp = [System.IO.File]::Create((Join-Path $Z $pname))
            $written = 0L
            while ($written -lt $target -and $in.Position -lt $in.Length) {
                $want = [int][Math]::Min([long]$buf.Length, [long]($target - $written))
                $n = $in.Read($buf, 0, $want)
                $outp.Write($buf, 0, $n); $written += $n
            }
            $outp.Close(); $parts += $pname; $i++
        }
    } finally { $in.Close() }
    $desc = if ($SMALL -gt 0 -and $parts.Count -gt $LargeParts) { "$LargeParts x $($PART / 1MB) MiB, then $($SMALL / 1MB) MiB" } else { "<= $($PART / 1MB) MiB" }
    Write-Host "  $name split into $($parts.Count) parts ($desc)"
    return $parts
}

"package directory: $Z"
if (-not $SkipTar) {
    Make-Tar 'molewhacker-newtrinos-runs.tar'      @('out/runs')
    Make-Tar 'molewhacker-newtrinos-ablation.tar'  @('out_ablation/runs')
    Make-Tar 'molewhacker-newtrinos-extension.tar' @('out_extension/runs', 'out_extension/_oom_20260915_1000', 'out_extension/_stopped_30seed_s23_20260914_2159', 'out_extension_nseed8/runs', 'out_extension_nseed8/_oom_20260915_1000', 'out_extension_nseed8/fresh')
    Make-Tar 'molewhacker-newtrinos-logs.tar'      @('out/logs')
}
$parts = @(Split-Archive 'molewhacker-newtrinos-ablation.tar')

Copy-Item (Join-Path $PSScriptRoot 'DATA-README.md') (Join-Path $Z 'DATA-README.md') -Force

"computing SHA256 checksums"
$files = @('molewhacker-newtrinos-runs.tar', 'molewhacker-newtrinos-ablation.tar', 'molewhacker-newtrinos-extension.tar', 'molewhacker-newtrinos-logs.tar') + $parts
$lines = foreach ($f in $files) { $h = (Get-FileHash (Join-Path $Z $f) -Algorithm SHA256).Hash.ToLower(); "$h  $f" }
[System.IO.File]::WriteAllLines((Join-Path $Z 'SHA256SUMS.txt'), $lines, [System.Text.UTF8Encoding]::new($false))
Get-Content (Join-Path $Z 'SHA256SUMS.txt')
"PACKAGE-DONE"
