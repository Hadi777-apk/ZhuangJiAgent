@echo off
chcp 65001>nul
echo ============================================
echo     ZhuangJi Agent - Install
echo ============================================
echo.
:: Read config
if exist "config\config.ini" (
    for /f "tokens=1,* delims==" %%a in ('findstr /b "install_path" config\config.ini') do set "INSTALL_PATH=%%b"
    for /f "tokens=1,* delims==" %%a in ('findstr /b "temp_path" config\config.ini') do set "TEMP_PATH=%%b"
    echo [OK] Config loaded
) else (
    echo [ERR] Config missing, creating default...
    if not exist "config" mkdir config
    echo [app] > config\config.ini
    echo name=ZhuangJiAgent>>config\config.ini
    echo version=1.0.0>>config\config.ini
    echo debug=false>>config\config.ini
    echo.>>config\config.ini
    echo [paths]>>config\config.ini
    echo install_path=%cd%\install>>config\config.ini
    echo temp_path=%cd%\temp>>config\config.ini
    set "INSTALL_PATH=%cd%\install"
    set "TEMP_PATH=%cd%\temp"
    echo [OK] Default config created
)
echo.
echo Install path: %INSTALL_PATH%
echo Temp path: %TEMP_PATH%
echo.
echo [1/3] Create install directory...
if not exist "%INSTALL_PATH%" (
    mkdir "%INSTALL_PATH%"
    echo [OK] Created: %INSTALL_PATH%
) else (
    echo [OK] Already exists: %INSTALL_PATH%
)
echo [2/3] Create temp directory...
if not exist "%TEMP_PATH%" (
    mkdir "%TEMP_PATH%"
    echo [OK] Created: %TEMP_PATH%
) else (
    echo [OK] Already exists: %TEMP_PATH%
)
echo [3/3] Verify directories...
if exist "%INSTALL_PATH%" (echo [OK] Install dir: OK) else (echo [ERR] Install dir: FAILED)
if exist "%TEMP_PATH%" (echo [OK] Temp dir: OK) else (echo [ERR] Temp dir: FAILED)
echo.
echo ============================================
echo Install complete!
echo.
echo Install: %INSTALL_PATH%
echo Temp: %TEMP_PATH%
echo ============================================
echo.
pause