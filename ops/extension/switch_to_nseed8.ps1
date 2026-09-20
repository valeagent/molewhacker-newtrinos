# Switch the DeepCore extension to the adapted seed count (14 Sep 2026, 22:00).
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File out_extension\switch_to_nseed8.ps1
#
# 1. Stop lane 2 (host lane2_extension.ps1 + its julia child running the 30-seed
#    MW s23 since 08:33) and move the partial cell directory aside.
# 2. Start lane 2 anew: queues\ext_deepcore_NO_nseed8.txt (MW s11, s23; --nseed 8)
#    -> out_extension_nseed8/
# 3. Start a waiter that runs MW s41 (--nseed 8) in lane 1 as soon as the
#    30-seed MW s11 julia process (lane 1, pid 4668) has exited.
# Lane 1 (30-seed MW s11, "protocol as specified") and the standalone MH s11 are
# not touched.
Set-Location (Split-Path -Parent $PSScriptRoot)   # repository root
function Note($s) { "$(Get-Date -Format s) $s" | Out-File "out_extension\chain_extension.progress" -Encoding ascii -Append }

# Verified 14 Sep 21:58: lane-2 host = powershell pid 22052 (lane2_extension.ps1,
# started 08:26), its julia child = pid 30836 (parent 22052). Julia children do
# not expose their command line, so the pids are pinned here; the parent link
# is re-checked before anything is stopped.
$hostPid = 22052; $juliaPid = 30836
$j = Get-CimInstance Win32_Process -Filter "ProcessId = $juliaPid"
$h = Get-CimInstance Win32_Process -Filter "ProcessId = $hostPid"
if (-not $j -or $j.Name -ne 'julia.exe' -or $j.ParentProcessId -ne $hostPid -or -not $h -or $h.CommandLine -notmatch 'lane2_extension\.ps1') {
    Write-Host "lane-2 processes do not match the pinned pids; nothing stopped, nothing started"; exit 1
}
foreach ($pid_ in @($hostPid, $juliaPid)) {
    Note "stopping pid $pid_ : lane 2, 30-seed MW s23 (switch to --nseed 8)"; Stop-Process -Id $pid_ -Force -ErrorAction SilentlyContinue
}
Start-Sleep 5
$arch = "out_extension\_stopped_30seed_s23_$(Get-Date -Format yyyyMMdd_HHmm)"
if (Test-Path "out_extension\runs\nu_dakamide_NO_mw_d24_B5e5_seed23") {
    New-Item -ItemType Directory -Path $arch -Force | Out-Null
    Move-Item "out_extension\runs\nu_dakamide_NO_mw_d24_B5e5_seed23" (Join-Path $arch "nu_dakamide_NO_mw_d24_B5e5_seed23") -Force
    Note "moved partial 30-seed s23 cell -> $arch"
}

$l2 = Start-Process -FilePath powershell -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "out_extension\lane2_nseed8.ps1" -WindowStyle Hidden -PassThru
$l1 = Start-Process -FilePath powershell -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "out_extension\lane1_after_nseed8.ps1" -WindowStyle Hidden -PassThru
Note "started lane 2 (--nseed 8: MW s11, s23) host pid $($l2.Id) and the lane-1 waiter (--nseed 8: MW s41 after pid 4668 exits) host pid $($l1.Id)"
Write-Host "switched: lane 2 host $($l2.Id), lane-1 waiter $($l1.Id)"
