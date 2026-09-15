# One MoleWhacker n_seed = 8 cell (d = 24, NO, B = 5e5) started either at a
# clock time (-StartAt "HH:mm") or after another process has exited (-AfterPid N),
# so that two MoleWhacker processes are not in their Hessian phase at once
# (the memory pattern that caused the OOM of 15 Sep 10:00).
#   powershell -File out_extension\lane_nseed8_delayed.ps1 -Seed 11 -StartAt 14:00
#   powershell -File out_extension\lane_nseed8_delayed.ps1 -Seed 41 -AfterPid 27480
param([int]$Seed, [string]$StartAt = "", [int]$AfterPid = 0)
Set-Location (Split-Path -Parent $PSScriptRoot)   # repository root
function Note($s) { "$(Get-Date -Format s) $s" | Out-File "out_extension\chain_extension.progress" -Encoding ascii -Append }
if ($StartAt) {
    $t = [datetime]::ParseExact($StartAt, "HH:mm", $null)
    if ($t -lt (Get-Date)) { $t = $t.AddDays(1) }
    Note "lane (MW n_seed = 8, seed $Seed): waiting until $($t.ToString('dd.MM HH:mm'))"
    while ((Get-Date) -lt $t) { Start-Sleep 60 }
}
if ($AfterPid -gt 0) {
    Note "lane (MW n_seed = 8, seed $Seed): waiting for pid $AfterPid to exit"
    while (Get-Process -Id $AfterPid -ErrorAction SilentlyContinue) { Start-Sleep 120 }
    Start-Sleep 30
}
$q = "queues\ext_deepcore_NO_nseed8_s$Seed.txt"
if (-not (Test-Path $q)) { "mw NO 5e5 $Seed dayabay,kamland,minos,deepcore" | Out-File $q -Encoding ascii }
$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$log = "out\logs\ext_deepcore_NO_nseed8_s${Seed}_$ts.log"
$p = Start-Process -FilePath julia -ArgumentList "--project=.", "-t", "4", "scripts\11_run_queue.jl", $q, "--out", "out_extension_nseed8", "--nseed", "8" `
    -RedirectStandardOutput $log -RedirectStandardError "$log.err" -NoNewWindow -PassThru
Note "lane (MW n_seed = 8, seed $Seed): started pid $($p.Id) log $log"
$p.WaitForExit()
Note "lane (MW n_seed = 8, seed $Seed): done (exit $($p.ExitCode))"
