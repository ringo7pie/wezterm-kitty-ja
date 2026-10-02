@echo off
rem Runs uninstall.ps1 in this folder. Extra arguments are passed through, e.g. -WhatIf
rem Always uses the Windows PowerShell that ships with Windows, by full path.
rem -ExecutionPolicy Bypass applies only to this one run; no system setting is changed.
setlocal
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0uninstall.ps1" %*
set "EXIT_CODE=%ERRORLEVEL%"
echo.
pause
exit /b %EXIT_CODE%
