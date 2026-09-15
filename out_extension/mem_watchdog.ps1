# Memory watchdog (15 Sep 2026). The OOM of 10:00 was a system-wide commit
# exhaustion (47 GB limit = 15.5 GB RAM + 32 GB system-managed pagefile) that
# took every julia process down at once. This script polls the commit charge
# every 5 s and, above the threshold, kills the julia process with the largest
# private memory (the one spiking) so that the others survive. It logs to the
# extension progress file. Exits when no julia process is left.
#   powershell -File out_extension\mem_watchdog.ps1 [-ThresholdGB 44]
param([double]$ThresholdGB = 44)
Set-Location (Split-Path -Parent $PSScriptRoot)   # repository root
function Note($s) { "$(Get-Date -Format s) $s" | Out-File "out_extension\chain_extension.progress" -Encoding ascii -Append }
Note "memory watchdog started (threshold $ThresholdGB GB commit)"
$peak = 0.0; $lastReport = Get-Date
while ($true) {
    $os = Get-CimInstance Win32_OperatingSystem
    $commit = ($os.TotalVirtualMemorySize - $os.FreeVirtualMemory) / 1MB
    $limit = $os.TotalVirtualMemorySize / 1MB
    if ($commit -gt $peak) { $peak = $commit }
    $js = @(Get-Process julia -ErrorAction SilentlyContinue)
    if ($js.Count -eq 0) { Note ("memory watchdog: no julia process left, exiting (peak commit {0:N1} GB)" -f $peak); break }
    if ($commit -gt $ThresholdGB) {
        $victim = $js | Sort-Object PrivateMemorySize64 -Descending | Select-Object -First 1
        Note ("memory watchdog: commit {0:N1} of {1:N1} GB > {2} GB - killing julia pid {3} (private {4:N1} GB, started {5:HH:mm})" -f $commit, $limit, $ThresholdGB, $victim.Id, ($victim.PrivateMemorySize64 / 1GB), $victim.StartTime)
        Stop-Process -Id $victim.Id -Force -ErrorAction SilentlyContinue
        Start-Sleep 20
        continue
    }
    if (((Get-Date) - $lastReport).TotalMinutes -ge 30) {
        $lastReport = Get-Date
        Note ("memory watchdog: commit {0:N1} of {1:N1} GB (peak {2:N1}); julia private GB: {3}" -f $commit, $limit, $peak, (($js | ForEach-Object { "{0}={1:N1}" -f $_.Id, ($_.PrivateMemorySize64 / 1GB) }) -join ", "))
    }
    Start-Sleep 5
}
