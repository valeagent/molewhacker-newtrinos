# DeepCore extension chain (approved 13 Sep 2026, 15:00; lane 2 redefined 21:50
# after the IO smoke test showed that the DeepCore module supports the normal
# ordering only, see queues/ext_deepcore_IO.txt).
# 1. Wait until the seed-41 T_max ablation cells of both orderings have written
#    a non-empty result.h5 (they run in the two ablation queue processes after
#    seed 23).
# 2. Start two lanes of the extension "Towards a global fit": Daya Bay +
#    KamLAND + MINOS + IceCube DeepCore, d = 24, normal ordering, 4 threads each.
#      lane 1: MoleWhacker seed 11 (protocol T_max = 20), then MH seed 11        -> out_extension/
#      lane 2: MoleWhacker seeds 23 and 41 (protocol),                           -> out_extension/
#              then MoleWhacker seed 11 with the cap lifted (--tmax 100000)      -> out_extension_tmax/
# 3. When both lanes are done, fold seed 41 into the T_max study and export.
Set-Location (Split-Path -Parent $PSScriptRoot)   # repository root
$want = @("out_ablation\runs\nu_dakami_NO_mw_d11_B5e5_seed41\result.h5",
          "out_ablation\runs\nu_dakami_IO_mw_d11_B5e5_seed41\result.h5")
function AllDone($files) { foreach ($f in $files) { if (-not (Test-Path $f)) { return $false }; if ((Get-Item $f).Length -eq 0) { return $false } }; return $true }
function Note($s) { "$(Get-Date -Format s) $s" | Out-File "out_extension\chain_extension.progress" -Encoding ascii -Append }
while (-not (AllDone $want)) { Start-Sleep 120 }
Start-Sleep 120   # let metadata.json / summary.json land, let the queue processes exit
Note "seed 41 finished, starting extension lanes"

$ts = Get-Date -Format "yyyyMMdd_HHmmss"
# lane 1: one Julia process for the two protocol cells (MW, MH; seed 11)
$log1 = "out\logs\ext_deepcore_NO_$ts.log"
$p1 = Start-Process -FilePath julia -ArgumentList "--project=.", "-t", "4", "scripts\11_run_queue.jl", "queues\ext_deepcore_NO.txt", "--out", "out_extension" `
    -RedirectStandardOutput $log1 -RedirectStandardError "$log1.err" -NoNewWindow -PassThru
Note "lane 1 (MW s11 + MH s11) pid $($p1.Id) log $log1"
# lane 2: a PowerShell job that runs the seed queue and then the uncapped queue sequentially
$lane2 = {
    param($root, $ts)
    Set-Location $root
    $logA = "out\logs\ext_deepcore_NO_seeds_$ts.log"
    $pa = Start-Process -FilePath julia -ArgumentList "--project=.", "-t", "4", "scripts\11_run_queue.jl", "queues\ext_deepcore_NO_seeds.txt", "--out", "out_extension" `
        -RedirectStandardOutput $logA -RedirectStandardError "$logA.err" -NoNewWindow -PassThru -Wait
    $logB = "out\logs\ext_deepcore_NO_uncapped_$ts.log"
    $pb = Start-Process -FilePath julia -ArgumentList "--project=.", "-t", "4", "scripts\11_run_queue.jl", "queues\ext_deepcore_NO_uncapped.txt", "--out", "out_extension_tmax", "--tmax", "100000" `
        -RedirectStandardOutput $logB -RedirectStandardError "$logB.err" -NoNewWindow -PassThru -Wait
}
$job = Start-Job -ScriptBlock $lane2 -ArgumentList (Get-Location).Path, $ts
Note "lane 2 (MW s23, s41, then MW s11 uncapped) job $($job.Id)"
$p1.WaitForExit()
Note "lane 1 done"
Wait-Job $job | Out-Null
Note "lane 2 done"

# fold seed 41 into the T_max study and export to the thesis
$ts2 = Get-Date -Format "yyyyMMdd_HHmmss"
$log2 = "out\logs\73_tmax_seed41_$ts2.log"
$q = Start-Process -FilePath julia -ArgumentList "--project=.", "-t", "4", "scripts\73_tmax_study.jl", "--fresh", "--finished-only" `
    -RedirectStandardOutput $log2 -RedirectStandardError "$log2.err" -NoNewWindow -PassThru
$q.WaitForExit()
powershell -NoProfile -File scripts\90_export_thesis.ps1 | Out-File "out\logs\90_export_$ts2.log" -Encoding utf8
"$(Get-Date -Format s) extension chain done; tmax study exit $($q.ExitCode)" | Out-File "out_extension\chain_extension.done" -Encoding ascii
