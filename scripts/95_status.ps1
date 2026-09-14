# Live status of the long runs (T_max ablation, DeepCore extension) and the
# chains that drive them. Read-only.
#   .\scripts\95_status.ps1            one snapshot
#   .\scripts\95_status.ps1 -Watch     refresh every 60 s (Ctrl+C to stop)
# or double-click status.cmd in the repository root.
param([switch]$Watch, [int]$Every = 60)
Set-Location (Split-Path -Parent $PSScriptRoot)

$cells = @(
    @{ n = "T_max ablation  seed 11  NO"; d = "out_ablation\runs\nu_dakami_NO_mw_d11_B5e5_seed11" },
    @{ n = "T_max ablation  seed 11  IO"; d = "out_ablation\runs\nu_dakami_IO_mw_d11_B5e5_seed11" },
    @{ n = "T_max ablation  seed 23  NO"; d = "out_ablation\runs\nu_dakami_NO_mw_d11_B5e5_seed23" },
    @{ n = "T_max ablation  seed 23  IO"; d = "out_ablation\runs\nu_dakami_IO_mw_d11_B5e5_seed23" },
    @{ n = "T_max ablation  seed 41  NO"; d = "out_ablation\runs\nu_dakami_NO_mw_d11_B5e5_seed41" },
    @{ n = "T_max ablation  seed 41  IO"; d = "out_ablation\runs\nu_dakami_IO_mw_d11_B5e5_seed41" },
    @{ n = "DeepCore ext.   MoleWhacker s11 NO"; d = "out_extension\runs\nu_dakamide_NO_mw_d24_B5e5_seed11" },
    @{ n = "DeepCore ext.   MH reference s11 NO"; d = "out_extension\runs\nu_dakamide_NO_mh_d24_B5e5_seed11" },
    @{ n = "DeepCore ext.   MoleWhacker s23 NO"; d = "out_extension\runs\nu_dakamide_NO_mw_d24_B5e5_seed23" },
    @{ n = "DeepCore ext.   MoleWhacker s41 NO"; d = "out_extension\runs\nu_dakamide_NO_mw_d24_B5e5_seed41" },
    @{ n = "DeepCore ext.   MW cap lifted s11 NO"; d = "out_extension_tmax\runs\nu_dakamide_NO_mw_d24_B5e5_seed11" }
)

function Fmt-Span([TimeSpan]$t) { if ($t.TotalHours -ge 1) { "{0:N1} h" -f $t.TotalHours } else { "{0:N0} min" -f $t.TotalMinutes } }

function Show-Status {
    $now = Get-Date
    Write-Host ("=== neutrino runs - {0} ===" -f $now.ToString("ddd dd.MM.yyyy HH:mm:ss")) -ForegroundColor Cyan
    $os = Get-CimInstance Win32_OperatingSystem
    $bat = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
    $power = if ($bat -and $bat.BatteryStatus -ne 2) { "ON BATTERY ({0} %)" -f $bat.EstimatedChargeRemaining } else { "on mains power" }
    Write-Host ("power: {0}   free RAM: {1:N1} of {2:N1} GB   uptime: {3}" -f $power, ($os.FreePhysicalMemory / 1MB), ($os.TotalVisibleMemorySize / 1MB), (Fmt-Span ($now - $os.LastBootUpTime)))
    Write-Host ""
    Write-Host "Julia processes (each queue lane is one process):" -ForegroundColor Yellow
    $js = @(Get-Process julia -ErrorAction SilentlyContinue)
    if ($js.Count -eq 0) { Write-Host "  none running" -ForegroundColor Red }
    $cpu0 = @{}; foreach ($p in $js) { $cpu0[$p.Id] = $p.TotalProcessorTime.TotalSeconds }
    if ($js.Count -gt 0) { Start-Sleep -Seconds 3 }
    foreach ($p in $js) {
        $p.Refresh()
        $busy = ($p.TotalProcessorTime.TotalSeconds - $cpu0[$p.Id]) / 3.0 * 100   # % of one core over the last 3 s
        $tag = if ($busy -ge 20) { "busy {0,4:N0} % of a core" -f $busy } else { "IDLE? ({0:N0} %)" -f $busy }
        $col = if ($busy -ge 20) { "Gray" } else { "Red" }
        Write-Host ("  pid {0,-6} since {1}  running {2,-8}  cpu {3,6:N0} min  ram {4,5:N0} MB  {5}" -f $p.Id, $p.StartTime.ToString("dd.MM HH:mm"), (Fmt-Span ($now - $p.StartTime)), $p.TotalProcessorTime.TotalMinutes, ($p.WorkingSet64 / 1MB), $tag) -ForegroundColor $col
    }
    Write-Host ""
    Write-Host "Cells:" -ForegroundColor Yellow
    foreach ($c in $cells) {
        $r = Join-Path $c.d "result.h5"
        if ((Test-Path $r) -and (Get-Item $r).Length -gt 0) {
            Write-Host ("  {0,-34} DONE     finished {1}" -f $c.n, (Get-Item $r).LastWriteTime.ToString("dd.MM HH:mm")) -ForegroundColor Green
        } elseif (Test-Path $c.d) {
            $t0 = (Get-Item $c.d).CreationTime
            Write-Host ("  {0,-34} RUNNING  since {1} ({2})" -f $c.n, $t0.ToString("dd.MM HH:mm"), (Fmt-Span ($now - $t0))) -ForegroundColor Yellow
        } else {
            Write-Host ("  {0,-34} waiting" -f $c.n) -ForegroundColor DarkGray
        }
    }
    Write-Host ""
    Write-Host "MoleWhacker progress (last iteration line per lane log):" -ForegroundColor Yellow
    $logs = Get-ChildItem out\logs -Filter "*.log.err" -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "^(ablation_tmax|ext_deepcore)_" } | Sort-Object LastWriteTime -Descending | Select-Object -First 4
    foreach ($l in $logs) {
        $m = Select-String -Path $l.FullName -Pattern "Iteration (\d+): Efficiency=[0-9.e+-]+, Effective sample size=([0-9.e+-]+)" | Select-Object -Last 1
        $age = Fmt-Span ($now - $l.LastWriteTime)
        if ($m) {
            Write-Host ("  {0,-42} iteration {1,4}  ESS {2,8:N0}   (log written {3} ago)" -f $l.Name, $m.Matches[0].Groups[1].Value, [double]$m.Matches[0].Groups[2].Value, $age)
        } else {
            $last = Get-Content $l.FullName -Tail 1 -ErrorAction SilentlyContinue
            if ($last.Length -gt 100) { $last = $last.Substring(0, 100) + "..." }
            Write-Host ("  {0,-42} (log written {1} ago) {2}" -f $l.Name, $age, $last)
        }
    }
    Write-Host ""
    Write-Host "Chains:" -ForegroundColor Yellow
    if (Test-Path out_ablation\chain_tmax_seed23.done) { Write-Host "  seed-23 chain: done (T_max figure rebuilt and exported)" -ForegroundColor Green } else { Write-Host "  seed-23 chain: waiting for the two seed-23 results" }
    if (Test-Path out_extension\chain_extension.done) { Write-Host "  extension chain: done" -ForegroundColor Green }
    elseif (Test-Path out_extension\chain_extension.progress) { Get-Content out_extension\chain_extension.progress -Tail 6 | ForEach-Object { Write-Host "  extension chain: $_" } }
    else { Write-Host "  extension chain: waiting for the two seed-41 results, then starts the DeepCore lanes" }
    Write-Host ""
    Write-Host "Expected (revised Mon 08:30 after lane 2 had to be relaunched): lane 1 = MW s11 (started 02:25) then MH s11 (~18-22 h) -> ~Tue 06:00-12:00;" -ForegroundColor DarkGray
    Write-Host "lane 2 = MW s23, MW s41 (~4-8 h each), then MW s11 uncapped (full budget, ~15-20 h) -> ~Tue 10:00-18:00. Analysis + figures follow the same day." -ForegroundColor DarkGray
    Write-Host "A julia line in RED (IDLE?) for more than a few minutes means a hung lane: tell the agent." -ForegroundColor DarkGray
    Write-Host "Extension is normal ordering only (the DeepCore module supports NO only; see queues\ext_deepcore_IO.txt)." -ForegroundColor DarkGray
    Write-Host "Logs: out\logs\*.log.err  (flushed in chunks: gaps of 1-2 h are normal; 'busy' above is the reliable sign of life)" -ForegroundColor DarkGray
}

if ($Watch) {
    while ($true) { Clear-Host; Show-Status; Write-Host ""; Write-Host ("refreshing every {0} s - Ctrl+C to stop" -f $Every) -ForegroundColor DarkGray; Start-Sleep $Every }
} else {
    Show-Status
}
