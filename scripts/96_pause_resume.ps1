# Pause / resume the running julia cells at the operating-system level
# (NtSuspendProcess / NtResumeProcess). A suspended process keeps everything
# in memory and continues exactly where it was; no progress is lost, only wall
# time. Use it when the laptop is needed for something memory-hungry (Chrome,
# AnyDesk, ...): while the MoleWhacker processes are suspended they cannot
# produce the multi-GB Hessian spikes that caused the out-of-memory event of
# 15 Sep 2026, and they release their CPU.
#
#   .\scripts\96_pause_resume.ps1 pause          suspend the MoleWhacker cells (MH keeps running)
#   .\scripts\96_pause_resume.ps1 pause -All     suspend every julia process, MH included
#   .\scripts\96_pause_resume.ps1 resume         resume every julia process (safe to repeat)
#   .\scripts\96_pause_resume.ps1 status         who is suspended
# or double-click pause.cmd / resume.cmd in the repository root.
#
# The MH processes are recognised by their pids in out_extension\mh_pids.txt
# (written by the relaunch script); everything else that is julia.exe is a
# MoleWhacker lane. The waiter/host PowerShell scripts are not touched: a
# suspended lane is still "alive", so a waiter keeps waiting.
param([Parameter(Position = 0)][ValidateSet("pause", "resume", "status")][string]$Action = "status", [switch]$All)
Set-Location (Split-Path -Parent $PSScriptRoot)
function Note($s) { "$(Get-Date -Format s) $s" | Out-File "out_extension\chain_extension.progress" -Encoding ascii -Append }
$sig = '[DllImport("ntdll.dll")] public static extern int NtSuspendProcess(IntPtr h); [DllImport("ntdll.dll")] public static extern int NtResumeProcess(IntPtr h);'
$nt = Add-Type -MemberDefinition $sig -Name NtProc -Namespace Win32Runs -PassThru
$mhPids = @(); if (Test-Path out_extension\mh_pids.txt) { $mhPids = @(Get-Content out_extension\mh_pids.txt | ForEach-Object { [int]$_ }) }
$js = @(Get-Process julia -ErrorAction SilentlyContinue)
if ($js.Count -eq 0) { Write-Host "no julia process running"; exit 0 }

function Is-Suspended($p) {
    # every thread in a Wait state with reason Suspended (5)
    $ths = @($p.Threads); if ($ths.Count -eq 0) { return $false }
    return -not ($ths | Where-Object { -not ($_.ThreadState -eq 'Wait' -and $_.WaitReason -eq 'Suspended') })
}

switch ($Action) {
    "pause" {
        foreach ($p in $js) {
            $isMH = $mhPids -contains $p.Id
            if ($isMH -and -not $All) { Write-Host ("  pid {0,-6} MH reference       left running" -f $p.Id); continue }
            if (Is-Suspended $p) { Write-Host ("  pid {0,-6} already suspended" -f $p.Id); continue }
            $rc = $nt::NtSuspendProcess($p.Handle)
            $kind = if ($isMH) { "MH reference" } else { "MoleWhacker lane" }
            Write-Host ("  pid {0,-6} {1,-18} SUSPENDED (rc {2})" -f $p.Id, $kind, $rc)
            Note "PAUSE: suspended julia pid $($p.Id) ($kind) by user request"
        }
        Write-Host "paused. Run '.\scripts\96_pause_resume.ps1 resume' (or resume.cmd) to continue." -ForegroundColor Yellow
    }
    "resume" {
        foreach ($p in $js) {
            if (-not (Is-Suspended $p)) { Write-Host ("  pid {0,-6} running" -f $p.Id); continue }
            $rc = $nt::NtResumeProcess($p.Handle)
            Write-Host ("  pid {0,-6} RESUMED (rc {1})" -f $p.Id, $rc)
            Note "RESUME: resumed julia pid $($p.Id)"
        }
    }
    "status" {
        foreach ($p in $js) {
            $kind = if ($mhPids -contains $p.Id) { "MH reference" } else { "MoleWhacker lane" }
            $st = if (Is-Suspended $p) { "SUSPENDED" } else { "running" }
            Write-Host ("  pid {0,-6} {1,-18} {2}  since {3:dd.MM HH:mm}  cpu {4:N0} min" -f $p.Id, $kind, $st, $p.StartTime, $p.TotalProcessorTime.TotalMinutes)
        }
    }
}
