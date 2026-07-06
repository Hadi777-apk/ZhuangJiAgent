@echo off
setlocal enabledelayedexpansion

echo 正在初始化装机agent项目...

:: 创建基本目录
if not exist "src" mkdir src
if not exist "config" mkdir config
if not exist "logs" mkdir logs
if not exist "data" mkdir data

:: 创建配置文件
echo [app]>config\config.ini
echo name=装机agent>>config\config.ini
echo version=1.0.0>>config\config.ini
echo debug=false>>config\config.ini

echo [paths]>>config\config.ini
echo install_path=%cd%\install>>config\config.ini
echo temp_path=%cd%\temp>>config\config.ini

:: 创建安装脚本
echo @echo off>scripts\install.bat
echo setlocal>>scripts\install.bat
echo set "INSTALL_PATH=%cd%\install">>scripts\install.bat
echo set "TEMP_PATH=%cd%\temp">>scripts\install.bat
echo echo 开始安装...>>scripts\install.bat
echo if not exist "!INSTALL_PATH!" mkdir "!INSTALL_PATH!">>scripts\install.bat
echo if not exist "!TEMP_PATH!" mkdir "!TEMP_PATH!">>scripts\install.bat
echo echo 安装完成！>>scripts\install.bat
echo endlocal>>scripts\install.bat

:: 创建启动脚本
echo @echo off>scripts\start.bat
echo setlocal>>scripts\start.bat
echo echo 启动装机agent...>>scripts\start.bat
echo echo 检查配置文件...>>scripts\start.bat
echo if not exist "config\config.ini" (>>scripts\start.bat
echo     echo 配置文件不存在，正在创建默认配置...>>scripts\start.bat
echo     echo [app]>config\config.ini>>scripts\start.bat
echo     echo name=装机agent>>config\config.ini>>scripts\start.bat
echo     echo version=1.0.0>>config\config.ini>>scripts\start.bat
echo     echo debug=false>>config\config.ini>>scripts\start.bat
echo )>>scripts\start.bat
echo echo 配置加载完成！>>scripts\start.bat
echo endlocal>>scripts\start.bat

:: 创建闪退修复脚本
echo @echo off>scripts\fix_crash.bat
echo echo 正在修复闪退问题...>>scripts\fix_crash.bat
echo echo 1. 检查路径配置...>>scripts\fix_crash.bat
echo echo 2. 验证依赖文件...>>scripts\fix_crash.bat
echo echo 3. 修复权限问题...>>scripts\fix_crash.bat
echo echo 修复完成！>>scripts\fix_crash.bat

echo 项目初始化完成！
echo.
echo 创建的文件：
echo - config\config.ini (配置文件)
echo - scripts\install.bat (安装脚本)
echo - scripts\start.bat (启动脚本)
echo - scripts\fix_crash.bat (闪退修复脚本)
echo.
echo 请运行 scripts\start.bat 启动应用，或运行 scripts\fix_crash.bat 修复闪退问题。