# =============================================================================
# 85_extension_analysis.ps1 - the complete post-run analysis of the extension
# "Towards a global fit" (Daya Bay + KamLAND + MINOS + IceCube DeepCore, d = 24).
#
# Output roots (final design, 14/15 Sep 2026):
#   out_extension\runs         MoleWhacker protocol cell (30 seeds) s11 + the MH
#                              reference: two chains of B = 2.5e5, seeds 11 and 23
#                              (memory-staggered relaunch after the OOM of 15 Sep)
#   out_extension_nseed8\runs  MoleWhacker with n_seed = 8, seeds 11/23/41 (the result set)
# The MH chains are COPIED into out_extension_nseed8\runs (step 0) so that
# 20_aggregate.jl finds the pooled reference for the agreement table of that root.
#
#   powershell -File scripts\85_extension_analysis.ps1 [-Threads 4] [-NFresh 30000] [-SkipFresh]
#
# Steps (each script is idempotent, so the whole thing can be rerun as cells land):
#   0. copy the finished MH cell into out_extension_nseed8\runs
#   1. 20_aggregate.jl on out_extension_nseed8 and on out_extension (tag nu_dakamide_)
#   2. 81_extension_fresh.jl   fresh draws from every MoleWhacker mixture (~15 min per cell)
#   3. 82_extension_plots.jl   figures -> out\figs
#   4. 83_extension_tables.jl  LaTeX fragments -> out_extension_nseed8\tables
#   5. 90_export_thesis.ps1    copy the PDFs into the thesis repository
# =============================================================================
param([int]$Threads = 4, [int]$NFresh = 30000, [switch]$SkipFresh)
Set-Location (Split-Path -Parent $PSScriptRoot)
$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$log = "out\logs\85_extension_analysis_$ts.log"
$MAIN = "out_extension_nseed8"; $PROTO = "out_extension"
function Step($name, $jargs) {   # not $args: that is PowerShell's automatic variable and arrives empty
    Write-Host ("{0}  {1}" -f (Get-Date -Format "HH:mm:ss"), $name)
    "=== $name ===" | Out-File $log -Append -Encoding utf8
    & julia --project=. -t $Threads @jargs 2>&1 | Tee-Object -FilePath $log -Append | Select-Object -Last 3
    if ($LASTEXITCODE -ne 0) { Write-Warning "$name exited with $LASTEXITCODE (see $log)" }
}
# 0. MH reference chains into the result root (each only when finished, i.e. a
#    non-empty result.h5): two chains of B = 2.5e5, seeds 11 and 23
#    (nu_dakamide_NO_mh_d24_B250000_seed*), pooled by 20_aggregate.jl.
$mhCells = @(Get-ChildItem (Join-Path $PROTO "runs") -Directory -Filter "nu_dakamide_NO_mh_*" -ErrorAction SilentlyContinue)
$nCopied = 0
foreach ($c in $mhCells) {
    $src = $c.FullName; $dst = Join-Path $MAIN ("runs\" + $c.Name)
    if (-not ((Test-Path "$src\result.h5") -and (Get-Item "$src\result.h5").Length -gt 0)) { continue }
    if (-not (Test-Path "$dst\result.h5") -or (Get-Item "$dst\result.h5").Length -ne (Get-Item "$src\result.h5").Length) {
        New-Item -ItemType Directory -Path $dst -Force | Out-Null
        Copy-Item "$src\*" $dst -Recurse -Force
        Write-Host ("{0}  MH chain {1} copied into {2}" -f (Get-Date -Format "HH:mm:ss"), $c.Name, $MAIN)
    }
    $nCopied++
}
if ($nCopied -lt 2) {
    Write-Warning ("only {0} of 2 MH reference chains finished: agreement and MH columns will be missing or provisional" -f $nCopied)
}
Step "aggregate $MAIN"  @("scripts\20_aggregate.jl", "--out", $MAIN,  "--tag", "nu_dakamide_")
Step "aggregate $PROTO" @("scripts\20_aggregate.jl", "--out", $PROTO, "--tag", "nu_dakamide_")
if (-not $SkipFresh) {
    Step "fresh draws" @("scripts\81_extension_fresh.jl", "--ext", $MAIN, "--ext-proto", $PROTO, "--N", "$NFresh")
}
Step "figures" @("scripts\82_extension_plots.jl", "--ext", $MAIN, "--ext-proto", $PROTO)
Step "tables"  @("scripts\83_extension_tables.jl", "--ext", $MAIN, "--ext-proto", $PROTO)
Write-Host ("{0}  export to thesis" -f (Get-Date -Format "HH:mm:ss"))
powershell -NoProfile -File scripts\90_export_thesis.ps1 | Tee-Object -FilePath $log -Append | Select-Object -Last 1
Write-Host "done - log: $log"
