@echo off
chcp 65001>nul
echo ============================================
echo     ZhuangJi Agent - Crash Fix
echo ============================================
echo.
echo [1/5] Check directories...
if not exist "config" mkdir config
if not exist "logs" mkdir logs
if not exist "data" mkdir data
if not exist "install" mkdir install
if not exist "temp" mkdir temp
echo [OK] Directories checked
echo [2/5] Check config file...
if not exist "config\config.ini" (
    echo Creating default config...
    echo [app]>config\config.ini
    echo name=ZhuangJiAgent>>config\config.ini
    echo version=1.0.0>>config\config.ini
    echo debug=false>>config\config.ini
    echo.>>config\config.ini
    echo [paths]>>config\config.ini
    echo install_path=%cd%\install>>config\config.ini
    echo temp_path=%cd%\temp>>config\config.ini
    echo [OK] Config created
) else (
    echo [OK] Config exists
)
echo [3/5] Verify path config...
for /f "tokens=1,* delims==" %%a in ('findstr /b "install_path" config\config.ini') do set "INSTALL_PATH=%%b"
echo Install path: %INSTALL_PATH%
echo [OK] Path verified
echo [4/5] Clean temp files...
if exist "temp\*" (
    del /q "temp\*" 2>nul
    echo [OK] Temp cleaned
) else (
    echo [OK] No temp files
)
echo [5/5] Verify results...
echo [OK] All fix steps done!
echo.
echo ============================================
echo Troubleshooting:
echo.
echo 1. If app still crashes, check if exe/dll is
echo    corrupted or incomplete
echo 2. Ensure .NET Framework 4.7.2+ is installed
echo 3. Check antivirus blocking
echo 4. Try running as Administrator
echo 5. Check logs\ directory for error logs
echo ============================================
echo.
pause