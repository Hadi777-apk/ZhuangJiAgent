@echo off
chcp 65001>nul
echo ============================================
echo     ZhuangJi Agent - Launcher
echo ============================================
echo.
if not exist "config\config.ini" (
  echo [ERR] Config missing, creating default...
  echo [app]>config\config.ini
  echo name=ZhuangJiAgent>>config\config.ini
  echo version=1.0.0>>config\config.ini
  echo debug=false>>config\config.ini
)
for /f "tokens=1,* delims==" %%a in ('findstr /b "name" config\config.ini') do set APP_NAME=%%b
echo App: %APP_NAME%
echo Path: %cd%
echo.
set MAIN_EXE=
if exist "bin\ZhuangJiAgent.exe" set MAIN_EXE=bin\ZhuangJiAgent.exe
if exist "src\ZhuangJiAgent.exe" set MAIN_EXE=src\ZhuangJiAgent.exe
if exist "ZhuangJiAgent.exe" set MAIN_EXE=ZhuangJiAgent.exe
if exist "app.exe" set MAIN_EXE=app.exe
if defined MAIN_EXE (
  echo [OK] Launching %APP_NAME%...
  start "" "%MAIN_EXE%"
  echo [OK] Launched
) else (
  echo [WARN] Main program not found
  echo.
  echo Place executable at one of:
  echo - bin\ZhuangJiAgent.exe
  echo - src\ZhuangJiAgent.exe
  echo - root\ZhuangJiAgent.exe
  echo.
  pause
)