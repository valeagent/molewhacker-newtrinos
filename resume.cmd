@echo off
rem Double-click: RESUME every suspended julia cell (safe to run at any time).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\96_pause_resume.ps1" resume
pause
