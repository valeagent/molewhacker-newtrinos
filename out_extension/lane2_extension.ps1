# Lane 2 of the DeepCore extension, run as a standalone process.
# (The original lane 2 was a PowerShell background job inside
# chain_extension.ps1; its julia.exe child hung at start-up on 14 Sep 02:21 -
# 9 MB, 0 CPU for six hours - so the job host and the child were killed at
# 08:30 and the lane was relaunched with this script, which starts julia the
# same way lane 1 does: a direct Start-Process from a normal PowerShell process.)
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File out_extension\lane2_extension.ps1
#
# Part A: MoleWhacker seeds 23 and 41 (protocol T_max = 20)        -> out_extension/
# Part B: MoleWhacker seed 11 with the cap lifted (--tmax 100000)  -> out_extension_tmax/
Set-Location (Split-Path -Parent $PSScriptRoot)   # repository root
function Note($s) { "$(Get-Date -Format s) $s" | Out-File "out_extension\chain_extension.progress" -Encoding ascii -Append }
$ts = Get-Date -Format "yyyyMMdd_HHmmss"

$logA = "out\logs\ext_deepcore_NO_seeds_$ts.log"
$pa = Start-Process -FilePath julia -ArgumentList "--project=.", "-t", "4", "scripts\11_run_queue.jl", "queues\ext_deepcore_NO_seeds.txt", "--out", "out_extension" `
    -RedirectStandardOutput $logA -RedirectStandardError "$logA.err" -NoNewWindow -PassThru
Note "lane 2 relaunched standalone: part A (MW s23, s41) pid $($pa.Id) log $logA"
$pa.WaitForExit()
Note "lane 2 part A done (exit $($pa.ExitCode))"

$logB = "out\logs\ext_deepcore_NO_uncapped_$ts.log"
$pb = Start-Process -FilePath julia -ArgumentList "--project=.", "-t", "4", "scripts\11_run_queue.jl", "queues\ext_deepcore_NO_uncapped.txt", "--out", "out_extension_tmax", "--tmax", "100000" `
    -RedirectStandardOutput $logB -RedirectStandardError "$logB.err" -NoNewWindow -PassThru
Note "lane 2 part B (MW s11 uncapped) pid $($pb.Id) log $logB"
$pb.WaitForExit()
Note "lane 2 part B done (exit $($pb.ExitCode)); lane 2 complete"
