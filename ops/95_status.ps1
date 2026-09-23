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
    @{ n = "DeepCore ext.   MW protocol (30 seeds) s11";  d = "out_extension\runs\nu_dakamide_NO_mw_d24_B5e5_seed11" },
    @{ n = "DeepCore ext.   MH reference s11 (B 2.5e5)";  d = "out_extension\runs\nu_dakamide_NO_mh_d24_B250000_seed11" },
    @{ n = "DeepCore ext.   MH reference s23 (B 2.5e5)";  d = "out_extension\runs\nu_dakamide_NO_mh_d24_B250000_seed23" },
    @{ n = "DeepCore ext.   MW n_seed=8 s23 (lane 2)";    d = "out_extension_nseed8\runs\nu_dakamide_NO_mw_d24_B5e5_seed23" },
    @{ n = "DeepCore ext.   MW n_seed=8 s11 (lane 1, since 14:02)   "; d = "out_extension_nseed8\runs\nu_dakamide_NO_mw_d24_B5e5_seed11" },
    @{ n = "DeepCore ext.   MW n_seed=8 s41 (lane 3, after s23+MH)"; d = "out_extension_nseed8\runs\nu_dakamide_NO_mw_d24_B5e5_seed41" }
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
        # a process suspended by pause.cmd / the sequencer has every thread in Wait/Suspended: intentional, not a hang
        $ths = @($p.Threads)
        $suspended = ($ths.Count -gt 0) -and -not ($ths | Where-Object { -not ($_.ThreadState -eq 'Wait' -and $_.WaitReason -eq 'Suspended') })
        $tag = if ($suspended) { "SUSPENDED (paused on purpose, nothing lost; resumes automatically or via resume.cmd)" }
               elseif ($busy -ge 20) { "busy {0,4:N0} % of a core" -f $busy } else { "IDLE? ({0:N0} %)" -f $busy }
        $col = if ($suspended) { "DarkYellow" } elseif ($busy -ge 20) { "Gray" } else { "Red" }
        Write-Host ("  pid {0,-6} since {1}  running {2,-8}  cpu {3,6:N0} min  ram {4,5:N0} MB  {5}" -f $p.Id, $p.StartTime.ToString("dd.MM HH:mm"), (Fmt-Span ($now - $p.StartTime)), $p.TotalProcessorTime.TotalMinutes, ($p.WorkingSet64 / 1MB), $tag) -ForegroundColor $col
    }
    Write-Host ""
    Write-Host "Cells:" -ForegroundColor Yellow
    foreach ($c in $cells) {
        $r = Join-Path $c.d "result.h5"
        if ((Test-Path $r) -and (Get-Item $r).Length -gt 0) {
            Write-Host ("  {0,-52} DONE     finished {1}" -f $c.n, (Get-Item $r).LastWriteTime.ToString("dd.MM HH:mm")) -ForegroundColor Green
        } elseif (Test-Path $c.d) {
            $t0 = (Get-Item $c.d).CreationTime
            Write-Host ("  {0,-52} RUNNING  since {1} ({2})" -f $c.n, $t0.ToString("dd.MM HH:mm"), (Fmt-Span ($now - $t0))) -ForegroundColor Yellow
        } else {
            Write-Host ("  {0,-52} waiting" -f $c.n) -ForegroundColor DarkGray
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
    Write-Host "Design (final, Mon 22:00; protocol cell landed Tue 00:21 and confirmed it): d = 24 costs are likelihood 0.22 s, gradient 6 s, Hessian 290 s;" -ForegroundColor DarkGray
    Write-Host "one L-BFGS seed runs to BAT's 1000-iteration limit (measured: 1090 gradients, 27 800 units per seed), so the protocol's 30 seeds cost" -ForegroundColor DarkGray
    Write-Host "836 621 units = 167 % of the 5e5 budget: the protocol cell stopped at iteration 0 after 21.9 h with N_eff = 18 (kept as the data point)." -ForegroundColor DarkGray
    Write-Host "OUT OF MEMORY, Tue 10:00: the commit charge hit the 47 GB limit (15.5 GB RAM + 32 GB pagefile) while two MW d = 24 processes were in" -ForegroundColor Red
    Write-Host "their Hessian phase; MH s11 (192 585 of 500 000 steps), MW n_seed = 8 s11 (iteration 15, ESS 927, eff 41 %) and MW n_seed = 8 s41 all" -ForegroundColor Red
    Write-Host "raised OutOfMemoryError and were lost (archived under */_oom_20260915_1000). Relaunched 10:32, memory-staggered:" -ForegroundColor Red
    Write-Host "  MH      = two cells, seeds 11 and 23, B = 2.5e5 each (same 5e5 total, pooled as at d = 11), two -t 1 processes -> ~Wed 02:00-07:00;" -ForegroundColor DarkGray
    Write-Host "  lane 2  = MW n_seed = 8 s23 (since 10:04, paused 15:24-18:41) -> ~Wed 03:00-05:00 (a cell needs ~14.5 h of compute);" -ForegroundColor DarkGray
    Write-Host "  lane 1  = MW n_seed = 8 s11 (since 14:02) SUSPENDED since 21:22 (four processes paged the RAM to death: MH fell to 30 %); resumes when s23 exits -> ~Wed 14:00-16:00;" -ForegroundColor DarkGray
    Write-Host "  lane 3  = MW n_seed = 8 s41 starts when s23 AND both MH chains have exited (max. 3 julia processes = no paging) -> ~Wed 18:00-20:00;" -ForegroundColor DarkGray
    Write-Host "  watchdog = ops\extension\mem_watchdog.ps1 kills the MoleWhacker lane with the least CPU time if the commit charge exceeds 44 GB." -ForegroundColor DarkGray
    Write-Host "PLEASE keep memory-heavy desktop applications closed (about 10 GB of commit) until Wed morning." -ForegroundColor Yellow
    Write-Host "Need the laptop for an hour? Double-click pause.cmd (suspends the MoleWhacker cells at OS level, nothing is lost, MH keeps running)," -ForegroundColor Yellow
    Write-Host "open what you need, and double-click resume.cmd when done. Each paused hour shifts the MW ETAs by one hour." -ForegroundColor Yellow
    Write-Host "Budget arithmetic for n_seed = 8: seeds 8 x 27 800 = 222 000 units (45 %), loop ~8 700 per iteration -> T_max = 20 reachable (s11 reached" -ForegroundColor DarkGray
    Write-Host "iteration 15 with 355 000 units before the OOM). MH ~Wed 03:00-04:00; analysis with two MW seeds Wed afternoon, refreshed with s41 when it lands." -ForegroundColor DarkGray
    Write-Host "A julia line in RED (IDLE?) for more than a few minutes means a hung lane: check its log and restart it." -ForegroundColor DarkGray
    Write-Host "Extension is normal ordering only (the DeepCore module supports NO only; see queues\ext_deepcore_IO.txt)." -ForegroundColor DarkGray
    Write-Host "Logs: the ext_deepcore_* logs stay EMPTY until a lane's julia process exits (PowerShell redirect buffers a few KB and these cells write" -ForegroundColor DarkGray
    Write-Host "only ~25 lines); no per-iteration progress is visible for the d = 24 cells. 'busy' above and a growing cpu column are the signs of life;" -ForegroundColor DarkGray
    Write-Host "a cell is finished when its result.h5 appears (DONE above)." -ForegroundColor DarkGray
}

if ($Watch) {
    while ($true) { Clear-Host; Show-Status; Write-Host ""; Write-Host ("refreshing every {0} s - Ctrl+C to stop" -f $Every) -ForegroundColor DarkGray; Start-Sleep $Every }
} else {
    Show-Status
}
