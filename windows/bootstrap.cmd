@echo off
rem Launch bootstrap.ps1 regardless of the execution policy (double-click friendly).
rem The script elevates itself via UAC.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0bootstrap.ps1" %*
if "%~1"=="" pause
