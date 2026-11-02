@echo off
rem Launch setup.ps1 regardless of the execution policy (double-click friendly)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1" %*
if "%~1"=="" pause
