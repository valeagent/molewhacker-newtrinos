@echo off
rem Double-click: live status of the neutrino runs (refreshes every 60 s, Ctrl+C or close window to stop).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp095_status.ps1" -Watch
