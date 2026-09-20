# MH reference of the DeepCore extension (seed 11, d = 24, NO), started as a
# third process on 14 Sep 2026 21:30 instead of after the MoleWhacker cell of
# lane 1 (measured cost: 5e5 sequential evaluations x 0.22 s = ~31 h; waiting
# for MW s11 would have pushed it to Wed night).
#
# Lane 1 still has "mh NO 5e5 11" in its queue. It is made to skip that cell by
# an EMPTY placeholder result.h5 in the MH cell directory (10_run_cell.jl skips
# when result.h5 exists; the status script treats a 0-byte file as not done).
# This process runs with --force and overwrites the placeholder at the end
# (JLD2 "w").
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File out_extension\mh_standalone.ps1
Set-Location (Split-Path -Parent $PSScriptRoot)   # repository root
function Note($s) { "$(Get-Date -Format s) $s" | Out-File "out_extension\chain_extension.progress" -Encoding ascii -Append }
$cell = "out_extension\runs\nu_dakamide_NO_mh_d24_B5e5_seed11"
New-Item -ItemType Directory -Path $cell -Force | Out-Null
if (-not (Test-Path "$cell\result.h5")) { New-Item -ItemType File -Path "$cell\result.h5" -Force | Out-Null }
$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$log = "out\logs\ext_deepcore_NO_mh_standalone_$ts.log"
$p = Start-Process -FilePath julia -ArgumentList "--project=.", "-t", "1", "scripts\10_run_cell.jl", "--alg", "mh", "--ordering", "NO", "--B", "5e5", "--seed", "11", "--exps", "dayabay,kamland,minos,deepcore", "--out", "out_extension", "--force" `
    -RedirectStandardOutput $log -RedirectStandardError "$log.err" -NoNewWindow -PassThru
Note "MH s11 started standalone (third process, -t 1) pid $($p.Id) log $log; placeholder result.h5 makes lane 1 skip its MH cell"
$p.WaitForExit()
Note "MH s11 standalone done (exit $($p.ExitCode))"
