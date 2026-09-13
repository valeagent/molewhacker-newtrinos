# Waits until the seed-23 T_max ablation cells of both orderings have written a
# non-empty result.h5 (seed 41 is on hold, see README-HOLD.md), then re-runs the
# T_max study with the fresh-draw check on all finished runs and exports the
# figures to the thesis. Started detached on 13 Sep 2026, ~13:15.
Set-Location (Split-Path -Parent $PSScriptRoot)   # repository root
$want = @("out_ablation\runs\nu_dakami_NO_mw_d11_B5e5_seed23\result.h5",
          "out_ablation\runs\nu_dakami_IO_mw_d11_B5e5_seed23\result.h5")
function AllDone { foreach ($f in $want) { if (-not (Test-Path $f)) { return $false }; if ((Get-Item $f).Length -eq 0) { return $false } }; return $true }
while (-not (AllDone)) { Start-Sleep 60 }
Start-Sleep 90   # let metadata.json / summary.json land as well
$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$log = "out\logs\73_tmax_seed23_$ts.log"
$p = Start-Process -FilePath julia -ArgumentList "--project=.", "-t", "4", "scripts\73_tmax_study.jl", "--fresh", "--finished-only" `
  -RedirectStandardOutput $log -RedirectStandardError "$log.err" -NoNewWindow -PassThru
$p.WaitForExit()
powershell -NoProfile -File scripts\90_export_thesis.ps1 | Out-File "out\logs\90_export_$ts.log" -Encoding utf8
"$(Get-Date -Format s) tmax study (seed 23) done, exit $($p.ExitCode), log $log" | Out-File "out_ablation\chain_tmax_seed23.done" -Encoding ascii
