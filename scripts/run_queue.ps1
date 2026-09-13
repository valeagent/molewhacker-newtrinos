# Launch one queue file as a hidden background Julia process.
# Usage (from the repo root):
#   powershell -ExecutionPolicy Bypass -File scripts\run_queue.ps1 -Queue wave2 -Threads 2
param(
    [Parameter(Mandatory = $true)][string]$Queue,
    [int]$Threads = 2
)
$root = Split-Path -Parent $PSScriptRoot   # repository root
$logs = Join-Path $root "out\logs"
New-Item -ItemType Directory -Force -Path $logs | Out-Null
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$queueFile = Join-Path $root ("queues\" + $Queue + ".txt")
if (-not (Test-Path $queueFile)) { throw "queue file not found: $queueFile" }
$log = Join-Path $logs ($Queue + "_" + $stamp + ".log")
$args = @("--project=$root", "-t", $Threads, "$root\scripts\11_run_queue.jl", $queueFile)
$p = Start-Process -FilePath "julia" -ArgumentList $args -WorkingDirectory $root `
    -RedirectStandardOutput $log -RedirectStandardError ($log + ".err") -WindowStyle Hidden -PassThru
Write-Host ("started {0} (pid {1}, {2} threads) -> {3}" -f $Queue, $p.Id, $Threads, $log)
