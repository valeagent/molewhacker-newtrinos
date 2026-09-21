# Builds the Zenodo data package of the neutrino application: plain tar
# archives of the raw per-cell run output (the files .gitignore excludes),
# split into 2 GiB parts where an archive exceeds that size (the layout of the
# benchmark archive 10.5281/zenodo.22228405), plus SHA256SUMS.txt and the
# DATA-README.md of this directory.
#
#   powershell -ExecutionPolicy Bypass -File ops\zenodo\build_package.ps1 [-PackageDir <dir>] [-SkipTar] [-PartSize <bytes>]
#
# PackageDir defaults to a sibling of the repository so that the 7.7 GB never
# enter git; -SkipTar re-splits and re-checksums existing archives. Takes a few
# minutes (I/O bound).
param(
    [string]$PackageDir = (Join-Path (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))) 'zenodo_package_neutrino'),
    [switch]$SkipTar,
    [long]$PartSize = 1GB
)
$ErrorActionPreference = 'Stop'
$REPO = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)   # ops/zenodo -> repository root
$Z = $PackageDir
$PART = [long]$PartSize
if ($PART -lt 64MB) { throw "PartSize must be at least 64 MiB (got $PART)" }
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
            $pname = '{0}.part-{1:d2}' -f $name, $i
            $outp = [System.IO.File]::Create((Join-Path $Z $pname))
            $written = 0L
            while ($written -lt $PART -and $in.Position -lt $in.Length) {
                $want = [int][Math]::Min([long]$buf.Length, [long]($PART - $written))
                $n = $in.Read($buf, 0, $want)
                $outp.Write($buf, 0, $n); $written += $n
            }
            $outp.Close(); $parts += $pname; $i++
        }
    } finally { $in.Close() }
    Write-Host "  $name split into $($parts.Count) parts of <= $($PART / 1MB) MiB"
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
