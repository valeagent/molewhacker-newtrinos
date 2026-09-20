# Third orchestrator (11 Sep, 21:05). Replaces the step-2 part of orchestrate_v2.ps1,
# whose nested run_queue.ps1 call for wave2_NO failed silently (wave2_NO was then
# started by hand at 21:04). Launches Julia directly and verifies each process.
#   when is IO 5e5 11 is done: stop D (15912) and D2 (27364), start nsref_NO,
#   nsref_IO (1 thread each) and wave2_IO (2 threads)
$root = Split-Path -Parent $PSScriptRoot   # repository root
$runs = Join-Path $root "out\runs"
$logs = Join-Path $root "out\logs"
$log = Join-Path $logs "orchestrator_v3.log"
function Log($msg) { $line = "{0:yyyy-MM-dd HH:mm:ss}  {1}" -f (Get-Date), $msg; Add-Content -Path $log -Value $line }
function StartQueue($queue, $threads) {
    $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $queueFile = Join-Path $root ("queues\" + $queue + ".txt")
    $out = Join-Path $logs ($queue + "_" + $stamp + ".log")
    $jargs = @("--project=$root", "-t", "$threads", "$root\scripts\11_run_queue.jl", $queueFile)
    try {
        $p = Start-Process -FilePath "julia" -ArgumentList $jargs -WorkingDirectory $root `
            -RedirectStandardOutput $out -RedirectStandardError ($out + ".err") -WindowStyle Hidden -PassThru
        Start-Sleep -Seconds 3
        $alive = $null -ne (Get-Process -Id $p.Id -ErrorAction SilentlyContinue)
        Log ("started {0} (pid {1}, {2} threads, alive={3}) -> {4}" -f $queue, $p.Id, $threads, $alive, $out)
    } catch {
        Log ("FAILED to start {0}: {1}" -f $queue, $_.Exception.Message)
    }
}
function Alive($procId) { return ($null -ne (Get-Process -Id $procId -ErrorAction SilentlyContinue)) }
Log "orchestrator v3 started"
$isIO = Join-Path $runs "nu_dakami_IO_is_d11_B5e5_seed11\summary.json"
while (-not (Test-Path $isIO)) { Start-Sleep -Seconds 60 }
Log "is IO 5e5 11 finished"
Start-Sleep -Seconds 90        # let the duplicate copy finish writing too
foreach ($p in @(15912, 27364)) {
    if (Alive $p) { Log "stopping pid $p (queue D or D2)"; Stop-Process -Id $p -Force -ErrorAction SilentlyContinue }
}
Start-Sleep -Seconds 5
StartQueue "nsref_NO" 1
StartQueue "nsref_IO" 1
StartQueue "wave2_IO" 2
Log "orchestrator v3 done"
