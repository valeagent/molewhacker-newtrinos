# Waits until the seed-11 T_max ablation cells of both orderings have written
# result.h5 (the queue processes then continue with seeds 23 and 41), runs the
# T_max study with the fresh-draw check on the finished runs only, and exports
# the figures to the thesis. Started detached on 12 Sep 2026, 22:30.
Set-Location (Split-Path -Parent $PSScriptRoot)   # repository root
$want = @("out_ablation\runs\nu_dakami_NO_mw_d11_B5e5_seed11\result.h5",
          "out_ablation\runs\nu_dakami_IO_mw_d11_B5e5_seed11\result.h5")
while (-not (($want | ForEach-Object { Test-Path $_ }) -notcontains $false)) { Start-Sleep 60 }
Start-Sleep 60   # let metadata.json land as well
$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$log = "out\logs\73_tmax_final_$ts.log"
$p = Start-Process -FilePath julia -ArgumentList "--project=.", "-t", "4", "scripts\73_tmax_study.jl", "--fresh", "--finished-only" `
  -RedirectStandardOutput $log -RedirectStandardError "$log.err" -NoNewWindow -PassThru
$p.WaitForExit()
powershell -NoProfile -File scripts\90_export_thesis.ps1 | Out-File "out\logs\90_export_$ts.log" -Encoding utf8
"$(Get-Date -Format s) tmax study done, exit $($p.ExitCode), log $log" | Out-File "out_ablation\chain_tmax_study.done" -Encoding ascii
