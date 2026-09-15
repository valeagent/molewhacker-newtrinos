# Relaunch after the out-of-memory event of 15 Sep 2026, ~10:00 (commit charge
# hit the 47 GB limit while two MoleWhacker d = 24 processes were in Hessian
# phases: MH s11 [192 585 of 500 000 steps], MW n_seed = 8 s11 [iteration 15,
# ESS 927] and MW n_seed = 8 s41 [first Hessian batch] all raised
# OutOfMemoryError; failed cells archived under */_oom_20260915_1000).
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File out_extension\relaunch_after_oom.ps1
#
# Design of the relaunch (memory-staggered, never two MoleWhacker processes in
# their Hessian phase at the same time if the timing holds):
#   MH reference : two cells, seeds 11 and 23, B = 2.5e5 each (four internal
#                  chains each; pooled = the same 5e5 total as one cell), run in
#                  parallel as two single-threaded processes -> ~Wed 02:00-07:00
#   MW n_seed=8  : s23 running in lane 2 since 10:04 (untouched);
#                  s11 starts at 14:00 (lane 1), when s23 should be in its loop;
#                  s41 starts when the s23 process has exited (lane 3)
#   watchdog     : out_extension\mem_watchdog.ps1 kills the julia process with
#                  the largest private memory if the commit charge exceeds 44 GB
Set-Location (Split-Path -Parent $PSScriptRoot)   # repository root
function Note($s) { "$(Get-Date -Format s) $s" | Out-File "out_extension\chain_extension.progress" -Encoding ascii -Append }
$ts = Get-Date -Format "yyyyMMdd_HHmmss"

# MH pair
foreach ($seed in 11, 23) {
    $log = "out\logs\ext_deepcore_NO_mh_B2.5e5_s${seed}_$ts.log"
    $p = Start-Process -FilePath julia -ArgumentList "--project=.", "-t", "1", "scripts\10_run_cell.jl", "--alg", "mh", "--ordering", "NO", "--B", "2.5e5", "--seed", "$seed", "--exps", "dayabay,kamland,minos,deepcore", "--out", "out_extension" `
        -RedirectStandardOutput $log -RedirectStandardError "$log.err" -WindowStyle Hidden -PassThru
    Note "MH reference seed $seed, B = 2.5e5, -t 1, pid $($p.Id) log $log"
}

# lane 1: MW s11 at 14:00; lane 3: MW s41 after the s23 process (pid 27480) exits
$l1 = Start-Process -FilePath powershell -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "out_extension\lane_nseed8_delayed.ps1", "-Seed", "11", "-StartAt", "14:00" -WindowStyle Hidden -PassThru
$l3 = Start-Process -FilePath powershell -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "out_extension\lane_nseed8_delayed.ps1", "-Seed", "41", "-AfterPid", "27480" -WindowStyle Hidden -PassThru
$wd = Start-Process -FilePath powershell -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "out_extension\mem_watchdog.ps1" -WindowStyle Hidden -PassThru
Note "hosts started: lane 1 (MW s11 at 14:00) pid $($l1.Id); lane 3 (MW s41 after pid 27480) pid $($l3.Id); memory watchdog pid $($wd.Id)"
Write-Host "relaunched: MH pair, lane 1 host $($l1.Id), lane 3 host $($l3.Id), watchdog $($wd.Id)"
