# =============================================================================
# 85_extension_analysis.ps1 - the complete post-run analysis of the extension
# "Towards a global fit" (Daya Bay + KamLAND + MINOS + IceCube DeepCore, d = 24).
# Run once the lanes of out_extension\chain_extension.ps1 have finished:
#
#   powershell -File scripts\85_extension_analysis.ps1 [-Threads 4] [-NFresh 30000] [-SkipFresh]
#
# Steps (each script is idempotent, so the whole thing can be rerun):
#   1. 20_aggregate.jl on out_extension (and out_extension_tmax if it exists)
#   2. 81_extension_fresh.jl   fresh draws from the MoleWhacker mixtures (~15 min per cell)
#   3. 82_extension_plots.jl   figures -> out\figs
#   4. 83_extension_tables.jl  LaTeX fragments -> out_extension\tables
#   5. 90_export_thesis.ps1    copy the PDFs into the thesis repository
# =============================================================================
param([int]$Threads = 4, [int]$NFresh = 30000, [switch]$SkipFresh)
Set-Location (Split-Path -Parent $PSScriptRoot)
$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$log = "out\logs\85_extension_analysis_$ts.log"
function Step($name, $args) {
    Write-Host ("{0}  {1}" -f (Get-Date -Format "HH:mm:ss"), $name)
    "=== $name ===" | Out-File $log -Append -Encoding utf8
    & julia --project=. -t $Threads @args 2>&1 | Tee-Object -FilePath $log -Append | Select-Object -Last 3
    if ($LASTEXITCODE -ne 0) { Write-Warning "$name exited with $LASTEXITCODE (see $log)" }
}
Step "aggregate out_extension"      @("scripts\20_aggregate.jl", "--out", "out_extension", "--tag", "nu_dakamide_")
if (Test-Path "out_extension_tmax\runs") {
    Step "aggregate out_extension_tmax" @("scripts\20_aggregate.jl", "--out", "out_extension_tmax", "--tag", "nu_dakamide_")
}
if (-not $SkipFresh) {
    Step "fresh draws" @("scripts\81_extension_fresh.jl", "--N", "$NFresh")
}
Step "figures" @("scripts\82_extension_plots.jl")
Step "tables"  @("scripts\83_extension_tables.jl")
Write-Host ("{0}  export to thesis" -f (Get-Date -Format "HH:mm:ss"))
powershell -NoProfile -File scripts\90_export_thesis.ps1 | Tee-Object -FilePath $log -Append | Select-Object -Last 1
Write-Host "done - log: $log"
