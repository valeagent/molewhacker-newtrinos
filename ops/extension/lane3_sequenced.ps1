# Sequenced tail of the extension (15 Sep 2026, 21:35). Replaces the lane-3
# waiter (lane_nseed8_delayed.ps1 -Seed 41 -AfterPid 27480), after the evening
# showed that the laptop's 15.5 GB of RAM carry three julia processes without
# paging but not four (two MoleWhacker lanes in their whacking loop, 10+ GB
# private each, plus the two MH chains: hard page faults of ~1000/s, the MH
# chains fell from 95 % to 30 % of a core). Order of events:
#   1. MW s11 (pid 26496) is suspended now and stays so while MW s23 (pid 27480)
#      finishes; when the s23 process exits, s11 is resumed.
#   2. MW s41 starts only when the two MH chains (pids in mh_pids.txt) have
#      exited as well, so that at most two MoleWhacker lanes and no chain share
#      the machine; it runs with --heap-size-hint=5G, which makes Julia's
#      garbage collector work against the growth of the loop's private memory.
#   powershell -File out_extension\lane3_sequenced.ps1 -S23Pid 27480 -S11Pid 26496
param([int]$S23Pid = 27480, [int]$S11Pid = 26496, [int]$Seed = 41)
Set-Location (Split-Path -Parent $PSScriptRoot)   # repository root
function Note($s) { "$(Get-Date -Format s) $s" | Out-File "out_extension\chain_extension.progress" -Encoding ascii -Append }
$sig = '[DllImport("ntdll.dll")] public static extern int NtSuspendProcess(IntPtr h); [DllImport("ntdll.dll")] public static extern int NtResumeProcess(IntPtr h);'
$nt = Add-Type -MemberDefinition $sig -Name NtProc -Namespace Win32Lane3 -PassThru

Note "lane 3 (sequenced): waiting for the s23 process (pid $S23Pid) to exit; s11 (pid $S11Pid) stays suspended meanwhile"
while (Get-Process -Id $S23Pid -ErrorAction SilentlyContinue) { Start-Sleep 60 }
Note "lane 3 (sequenced): s23 process exited"
$p11 = Get-Process -Id $S11Pid -ErrorAction SilentlyContinue
if ($p11) {
    $rc = $nt::NtResumeProcess($p11.Handle)
    Note "lane 3 (sequenced): resumed s11 (pid $S11Pid, rc $rc)"
} else {
    Note "lane 3 (sequenced): s11 process (pid $S11Pid) not found - nothing to resume"
}

$mhPids = @(); if (Test-Path out_extension\mh_pids.txt) { $mhPids = @(Get-Content out_extension\mh_pids.txt | ForEach-Object { [int]$_ }) }
Note ("lane 3 (sequenced): waiting for the MH chains (pids {0}) to exit before starting MW s{1}" -f ($mhPids -join ", "), $Seed)
while (@($mhPids | Where-Object { Get-Process -Id $_ -ErrorAction SilentlyContinue }).Count -gt 0) { Start-Sleep 120 }
Start-Sleep 30

$q = "queues\ext_deepcore_NO_nseed8_s$Seed.txt"
if (-not (Test-Path $q)) { "mw NO 5e5 $Seed dayabay,kamland,minos,deepcore" | Out-File $q -Encoding ascii }
$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$log = "out\logs\ext_deepcore_NO_nseed8_s${Seed}_$ts.log"
$p = Start-Process -FilePath julia -ArgumentList "--project=.", "-t", "4", "--heap-size-hint=5G", "scripts\11_run_queue.jl", $q, "--out", "out_extension_nseed8", "--nseed", "8" `
    -RedirectStandardOutput $log -RedirectStandardError "$log.err" -NoNewWindow -PassThru
Note "lane 3 (sequenced): started MW s$Seed pid $($p.Id) (--heap-size-hint=5G) log $log"
$p.WaitForExit()
Note "lane 3 (sequenced): MW s$Seed done (exit $($p.ExitCode))"
