# Second orchestrator (11 Sep, 19:40). State at launch:
#   * julia PIDs 14060 and 15912 are queues C and D (unknown which is which);
#     C is on its last cell (mh IO 5e5 23), D and D2 (pid 27364) are both on
#     is IO 5e5 11 and D would then continue with the two nsref runs.
#   * queue A was killed by mistake this morning: mh NO 5e5 11 must be redone.
# Steps:
#   1. when C's last cell is done: start redo_A and wave2_NO (2 threads each)
#   2. when is IO 5e5 11 is done: stop D and D2, start nsref_NO, nsref_IO
#      (1 thread each) and wave2_IO (2 threads)
$root = Split-Path -Parent $PSScriptRoot   # repository root
$runs = Join-Path $root "out\runs"
$log = Join-Path $root "out\logs\orchestrator_v2.log"
function Log($msg) { $line = "{0:yyyy-MM-dd HH:mm:ss}  {1}" -f (Get-Date), $msg; Add-Content -Path $log -Value $line; Write-Host $line }
function StartQueue($queue, $threads) {
    & powershell -ExecutionPolicy Bypass -File (Join-Path $root "scripts\run_queue.ps1") -Queue $queue -Threads $threads |
        ForEach-Object { Log $_ }
}
function Alive($procId) { return ($null -ne (Get-Process -Id $procId -ErrorAction SilentlyContinue)) }
$cd = @(14060, 15912)
$d2 = 27364
Log "orchestrator v2 started"

# ---- step 1
$cLast = Join-Path $runs "nu_dakami_IO_mh_d11_B5e5_seed23\summary.json"
while (-not (Test-Path $cLast)) { Start-Sleep -Seconds 60 }
Log "queue C finished its last cell; starting redo_A and wave2_NO"
StartQueue "redo_A" 2
StartQueue "wave2_NO" 2

# ---- step 2
$isIO = Join-Path $runs "nu_dakami_IO_is_d11_B5e5_seed11\summary.json"
while (-not (Test-Path $isIO)) { Start-Sleep -Seconds 60 }
Start-Sleep -Seconds 90        # let the second copy of the cell finish writing too
foreach ($p in $cd + @($d2)) {
    if (Alive $p) { Log "stopping pid $p (queue D or D2)"; Stop-Process -Id $p -Force -ErrorAction SilentlyContinue }
}
Start-Sleep -Seconds 5
Log "starting nsref_NO, nsref_IO, wave2_IO"
StartQueue "nsref_NO" 1
StartQueue "nsref_IO" 1
StartQueue "wave2_IO" 2
Log "orchestrator v2 done"
