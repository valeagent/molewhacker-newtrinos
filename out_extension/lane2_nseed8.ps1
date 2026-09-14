# Lane 2 of the DeepCore extension with the adapted seed count: MW s11, then
# MW s23, both --nseed 8, -> out_extension_nseed8/ (started by switch_to_nseed8.ps1).
Set-Location (Split-Path -Parent $PSScriptRoot)   # repository root
function Note($s) { "$(Get-Date -Format s) $s" | Out-File "out_extension\chain_extension.progress" -Encoding ascii -Append }
$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$log = "out\logs\ext_deepcore_NO_nseed8_$ts.log"
$p = Start-Process -FilePath julia -ArgumentList "--project=.", "-t", "4", "scripts\11_run_queue.jl", "queues\ext_deepcore_NO_nseed8.txt", "--out", "out_extension_nseed8", "--nseed", "8" `
    -RedirectStandardOutput $log -RedirectStandardError "$log.err" -NoNewWindow -PassThru
Note "lane 2 (--nseed 8: MW s11, then s23) pid $($p.Id) log $log"
$p.WaitForExit()
Note "lane 2 (--nseed 8) done (exit $($p.ExitCode))"
