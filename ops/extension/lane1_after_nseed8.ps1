# Lane-1 waiter: as soon as the 30-seed MW s11 julia process (lane 1, started
# 14 Sep 02:21) has exited, run MW s41 with --nseed 8 -> out_extension_nseed8/
# (started by switch_to_nseed8.ps1). Lane 1's queue continues with an MH line
# that is skipped (placeholder result.h5), so the process exits right after MW s11.
Set-Location (Split-Path -Parent $PSScriptRoot)   # repository root
function Note($s) { "$(Get-Date -Format s) $s" | Out-File "out_extension\chain_extension.progress" -Encoding ascii -Append }
# Lane-1 julia = pid 4668 (verified 14 Sep 21:58; julia children expose no
# command line, so the pid is pinned).
$lane1Pid = 4668
if (Get-Process -Id $lane1Pid -ErrorAction SilentlyContinue) {
    Note "lane-1 waiter: waiting for pid $lane1Pid (30-seed MW s11) to exit"
    while (Get-Process -Id $lane1Pid -ErrorAction SilentlyContinue) { Start-Sleep 120 }
    Start-Sleep 60
}
$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$log = "out\logs\ext_deepcore_NO_nseed8_s41_$ts.log"
$p = Start-Process -FilePath julia -ArgumentList "--project=.", "-t", "4", "scripts\11_run_queue.jl", "queues\ext_deepcore_NO_nseed8_s41.txt", "--out", "out_extension_nseed8", "--nseed", "8" `
    -RedirectStandardOutput $log -RedirectStandardError "$log.err" -NoNewWindow -PassThru
Note "lane 1 (--nseed 8: MW s41) pid $($p.Id) log $log"
$p.WaitForExit()
Note "lane 1 (--nseed 8: MW s41) done (exit $($p.ExitCode))"
