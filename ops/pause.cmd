@echo off
rem Double-click: PAUSE the MoleWhacker cells (suspend at OS level, no progress lost; MH keeps running).
rem Use before opening Chrome / AnyDesk etc.; double-click resume.cmd afterwards.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\scripts\96_pause_resume.ps1" pause
pause
