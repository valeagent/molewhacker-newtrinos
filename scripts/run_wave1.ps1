# Launch the four wave-1 queues as parallel Julia processes.
# Usage (from the repository root):
#   powershell -ExecutionPolicy Bypass -File scripts\run_wave1.ps1
$root = Split-Path -Parent $PSScriptRoot   # repository root
$logs = Join-Path $root "out\logs"
New-Item -ItemType Directory -Force -Path $logs | Out-Null
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$jobs = @(
    @{ q = "wave1_A"; t = 4 },
    @{ q = "wave1_B"; t = 4 },
    @{ q = "wave1_C"; t = 2 },
    @{ q = "wave1_D"; t = 2 }
)
foreach ($j in $jobs) {
    $queue = Join-Path $root ("queues\" + $j.q + ".txt")
    $log = Join-Path $logs ($j.q + "_" + $stamp + ".log")
    $args = @("--project=$root", "-t", $j.t, "$root\scripts\11_run_queue.jl", $queue)
    Start-Process -FilePath "julia" -ArgumentList $args -WorkingDirectory $root `
        -RedirectStandardOutput $log -RedirectStandardError ($log + ".err") -WindowStyle Hidden
    Write-Host "started $($j.q) -> $log"
}
