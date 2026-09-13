# Orchestrates the rest of the campaign without manual intervention:
#   1. when queue D has finished its first cell (NUTS NO 5e5), stop D and
#      restart it as D2 (same cells minus the nsref reference runs);
#   2. when queues A and B have exited, start the two nsref reference runs
#      (1 thread each) and the two wave-2 queues (2 threads each).
# Usage (from the repo root):
#   powershell -ExecutionPolicy Bypass -File scripts\orchestrate_wave1.ps1 `
#       -PidA 14060 -PidB 15912 -PidD 28944
param(
    [Parameter(Mandatory = $true)][int]$PidA,
    [Parameter(Mandatory = $true)][int]$PidB,
    [Parameter(Mandatory = $true)][int]$PidD
)
$root = Split-Path -Parent $PSScriptRoot   # repository root
$runs = Join-Path $root "out\runs"
$log = Join-Path $root "out\logs\orchestrator.log"
function Log($msg) { $line = "{0:yyyy-MM-dd HH:mm:ss}  {1}" -f (Get-Date), $msg; Add-Content -Path $log -Value $line; Write-Host $line }
function StartQueue($queue, $threads) {
    & powershell -ExecutionPolicy Bypass -File (Join-Path $root "scripts\run_queue.ps1") -Queue $queue -Threads $threads |
        ForEach-Object { Log $_ }
}
function Alive($procId) { return ($null -ne (Get-Process -Id $procId -ErrorAction SilentlyContinue)) }

Log "orchestrator started (A=$PidA B=$PidB D=$PidD)"

# ---- step 1: D -> D2 once the NUTS NO 5e5 cell is finished (or D moved on / died)
$nutsDone = Join-Path $runs "nu_dakami_NO_nuts_d11_B5e5_seed11\summary.json"
$nextCell = Join-Path $runs "nu_dakami_NO_ns_d11_B5e5_seed11"
while (-not (Test-Path $nutsDone) -and -not (Test-Path $nextCell) -and (Alive $PidD)) { Start-Sleep -Seconds 60 }
if (Alive $PidD) {
    Log "NUTS NO 5e5 finished (summary=$(Test-Path $nutsDone)); stopping D (pid $PidD) and starting D2"
    Stop-Process -Id $PidD -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 5
} else {
    Log "queue D exited on its own; starting D2 for the remaining cells"
}
StartQueue "wave1_D2" 2

# ---- step 2: wait for A and B, then start nsref x2 and wave2 x2
while ((Alive $PidA) -or (Alive $PidB)) { Start-Sleep -Seconds 120 }
Log "queues A and B finished; starting nsref_NO, nsref_IO, wave2_NO, wave2_IO"
StartQueue "nsref_NO" 1
StartQueue "nsref_IO" 1
StartQueue "wave2_NO" 2
StartQueue "wave2_IO" 2
Log "orchestrator done"
