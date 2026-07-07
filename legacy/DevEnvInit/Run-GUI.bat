@echo off
setlocal EnableExtensions

set "SCRIPT_DIR=%~dp0"
set "PS_SCRIPT=%SCRIPT_DIR%gui.ps1"

cd /d "%SCRIPT_DIR%"

net session >nul 2>&1
if not "%errorlevel%"=="0" (
    echo Requesting administrator permission...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -WorkingDirectory '%SCRIPT_DIR%' -Verb RunAs"
    exit /b
)

if not exist "%PS_SCRIPT%" (
    echo ERROR: gui.ps1 was not found.
    echo Path: "%PS_SCRIPT%"
    pause
    exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%"
set "EXIT_CODE=%ERRORLEVEL%"

echo.
echo GUI exited. Exit code: %EXIT_CODE%
pause
exit /b %EXIT_CODE%
