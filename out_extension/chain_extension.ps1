# DeepCore extension chain (approved 13 Sep 2026, 15:00).
# 1. Wait until the seed-41 T_max ablation cells of both orderings have written
#    a non-empty result.h5 (they run in the two ablation queue processes after
#    seed 23; ETA 06:00 on 14 Sep).
# 2. Start the two lanes of the extension "Towards a global fit": Daya Bay +
#    KamLAND + MINOS + IceCube DeepCore, d = 24, MoleWhacker (protocol) then MH,
#    one lane per ordering, 4 threads each, own output tree out_extension/.
# 3. When both lanes are done, fold seed 41 into the T_max study and export.
Set-Location (Split-Path -Parent $PSScriptRoot)   # repository root
$want = @("out_ablation\runs\nu_dakami_NO_mw_d11_B5e5_seed41\result.h5",
          "out_ablation\runs\nu_dakami_IO_mw_d11_B5e5_seed41\result.h5")
function AllDone($files) { foreach ($f in $files) { if (-not (Test-Path $f)) { return $false }; if ((Get-Item $f).Length -eq 0) { return $false } }; return $true }
while (-not (AllDone $want)) { Start-Sleep 120 }
Start-Sleep 120   # let metadata.json / summary.json land, let the queue processes exit
"$(Get-Date -Format s) seed 41 finished, starting extension lanes" | Out-File "out_extension\chain_extension.progress" -Encoding ascii -Append

$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$procs = @()
foreach ($ord in "NO", "IO") {
    $log = "out\logs\ext_deepcore_${ord}_$ts.log"
    $p = Start-Process -FilePath julia -ArgumentList "--project=.", "-t", "4", "scripts\11_run_queue.jl", "queues\ext_deepcore_$ord.txt", "--out", "out_extension" `
        -RedirectStandardOutput $log -RedirectStandardError "$log.err" -NoNewWindow -PassThru
    "$(Get-Date -Format s) lane $ord pid $($p.Id) log $log" | Out-File "out_extension\chain_extension.progress" -Encoding ascii -Append
    $procs += $p
}
foreach ($p in $procs) { $p.WaitForExit() }
"$(Get-Date -Format s) both lanes done" | Out-File "out_extension\chain_extension.progress" -Encoding ascii -Append

# fold seed 41 into the T_max study and export to the thesis
$ts2 = Get-Date -Format "yyyyMMdd_HHmmss"
$log2 = "out\logs\73_tmax_seed41_$ts2.log"
$q = Start-Process -FilePath julia -ArgumentList "--project=.", "-t", "4", "scripts\73_tmax_study.jl", "--fresh", "--finished-only" `
    -RedirectStandardOutput $log2 -RedirectStandardError "$log2.err" -NoNewWindow -PassThru
$q.WaitForExit()
powershell -NoProfile -File scripts\90_export_thesis.ps1 | Out-File "out\logs\90_export_$ts2.log" -Encoding utf8
"$(Get-Date -Format s) extension chain done; tmax study exit $($q.ExitCode)" | Out-File "out_extension\chain_extension.done" -Encoding ascii
