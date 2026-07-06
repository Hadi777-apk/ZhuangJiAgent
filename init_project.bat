@echo off
chcp 65001 >nul

echo 🚀 正在初始化装机agent项目...

:: 创建项目基本目录结构
if not exist "docs" mkdir docs
if not exist "src" mkdir src
if not exist "tests" mkdir tests
if not exist "scripts" mkdir scripts
if not exist "config" mkdir config
if not exist "logs" mkdir logs
if not exist "data" mkdir data

:: 创建 .gitignore 文件
echo # Byte-compiled / optimized / DLL files > .gitignore
echo __pycache__/ >> .gitignore
echo *.py[cod] >> .gitignore
echo *.pyo >> .gitignore
echo *.pyd >> .gitignore
echo PYZ*.pyz >> .gitignore
echo *.egg-info/ >> .gitignore
echo .eggs/ >> .gitignore
echo. >> .gitignore
echo # Distribution / packaging >> .gitignore
echo build/ >> .gitignore
echo dist/ >> .gitignore
echo *.egg >> .gitignore
echo. >> .gitignore
echo # Project specifics >> .gitignore
echo .codegraph/ >> .gitignore
echo .cursor/ >> .gitignore
echo .claude/ >> .gitignore
echo codemaps/ >> .gitignore
echo tasks/ >> .gitignore
echo logs/ >> .gitignore
echo data/*.db >> .gitignore
echo data/*.log >> .gitignore

:: 创建 README.md
echo # 装机agent > README.md
echo. >> README.md
echo ## 项目简介 >> README.md
echo 这是一个用于系统安装和配置的智能助手项目。 >> README.md
echo. >> README.md
echo ## 功能特性 >> README.md
echo - 自动化系统安装 >> README.md
echo - 智能配置管理 >> README.md
echo - 错误诊断和修复 >> README.md
echo - 界面化操作 >> README.md
echo. >> README.md
echo ## 快速开始 >> README.md
echo. >> README.md
echo ### 环境要求 >> README.md
echo - Windows 10/11 >> README.md
echo - .NET 6.0+ >> README.md
echo - Python 3.8+ >> README.md
echo. >> README.md
echo ### 安装步骤 >> README.md
echo 1. 克隆项目 >> README.md
echo 2. 运行初始化脚本 >> README.md
echo 3. 配置环境变量 >> README.md
echo 4. 启动应用 >> README.md
echo. >> README.md
echo ## 目录结构 >> README.md
echo. >> README.md
echo ``` >> README.md
echo. >> README.md
echo. >> README.md
echo ├── src/           # 源代码 >> README.md
echo ├── tests/         # 测试文件 >> README.md
echo ├── docs/          # 文档 >> README.md
echo ├── scripts/       # 脚本文件 >> README.md
echo ├── config/        # 配置文件 >> README.md
echo └── README.md      # 项目说明 >> README.md
echo. >> README.md
echo ``` >> README.md
echo. >> README.md
echo ## 开发指南 >> README.md
echo 详细开发指南请参考 [开发文档](docs/)。 >> README.md
echo. >> README.md
echo ## 许可证 >> README.md
echo MIT License >> README.md

:: 创建构建脚本
echo @echo off > scripts\build.bat
echo chcp 65001 ^>nul >> scripts\build.bat
echo. >> scripts\build.bat
echo echo 🔨 开始构建装机agent项目... >> scripts\build.bat
echo. >> scripts\build.bat
echo :: 清理旧构建文件 >> scripts\build.bat
echo if exist "build" rmdir /s /q build >> scripts\build.bat
echo mkdir build >> scripts\build.bat
echo. >> scripts\build.bat
echo :: 复制源文件 >> scripts\build.bat
echo if exist "src\" ( >> scripts\build.bat
echo     xcopy src\ build\ /E /I /H ^>nul 2^>^&1 || echo src目录为空，跳过复制 >> scripts\build.bat
echo ) else ( >> scripts\build.bat
echo     echo src目录不存在，跳过复制 >> scripts\build.bat
echo ) >> scripts\build.bat
echo. >> scripts\build.bat
echo echo ✅ 构建完成！输出目录: build\ >> scripts\build.bat

:: 创建测试脚本
echo @echo off > scripts\test.bat
echo chcp 65001 ^>nul >> scripts\test.bat
echo. >> scripts\test.bat
echo echo 🧪 运行测试... >> scripts\test.bat
echo. >> scripts\test.bat
echo :: 创建测试报告目录 >> scripts\test.bat
echo if not exist "reports" mkdir reports >> scripts\test.bat
echo. >> scripts\test.bat
echo :: 运行测试（示例） >> scripts\test.bat
echo if exist "tests\" ( >> scripts\test.bat
echo     echo 请手动运行测试：pytest tests/ -v >> scripts\test.bat
echo ) else ( >> scripts\test.bat
echo     echo tests目录不存在，请创建测试文件 >> scripts\test.bat
echo ) >> scripts\test.bat
echo. >> scripts\test.bat
echo echo ✅ 测试脚本准备完成！ >> scripts\test.bat

:: 创建配置文件
echo # 装机agent 配置文件 > config\config.ini
echo. >> config\config.ini
echo [app] >> config\config.ini
echo name = 装机agent >> config\config.ini
echo version = 1.0.0 >> config\config.ini
echo debug = false >> config\config.ini
echo. >> config\config.ini
echo [logging] >> config\config.ini
echo level = INFO >> config\config.ini
echo file = logs\app.log >> config\config.ini
echo. >> config\config.ini
echo [database] >> config\config.ini
echo type = sqlite >> config\config.ini
echo path = data\app.db >> config\config.ini
echo. >> config\config.ini
echo [ui] >> config\config.ini
echo theme = light >> config\config.ini
echo language = zh-CN >> config\config.ini
echo. >> config\config.ini
echo [features] >> config\config.ini
echo auto_update = true >> config\config.ini
echo telemetry = false >> config\config.ini

:: 创建启动脚本
echo @echo off > scripts\start.bat
echo chcp 65001 ^>nul >> scripts\start.bat
echo. >> scripts\start.bat
echo echo 🚀 启动装机agent... >> scripts\start.bat
echo. >> scripts\start.bat
echo if exist "src\main.py" ( >> scripts\start.bat
echo     python src\main.py >> scripts\start.bat
echo ) else if exist "src\Main.exe" ( >> scripts\start.bat
echo     start "" src\Main.exe >> scripts\start.bat
echo ) else ( >> scripts\start.bat
echo     echo 请先编译或运行主程序 >> scripts\start.bat
echo     echo 如果是 Python 项目，请创建 src\main.py >> scripts\start.bat
echo     echo 如果是 .NET 项目，请创建 src\Main.exe >> scripts\start.bat
echo ) >> scripts\start.bat

echo ✅ 项目初始化完成！
echo.
echo 📁 创建的目录和文件:
echo   ├── .gitignore
echo   ├── README.md
echo   ├── scripts\
echo   │   ├── build.bat
echo   │   ├── test.bat
echo   │   └── start.bat
echo   ├── src\
echo   ├── tests\
echo   ├── docs\
echo   ├── config\
echo   ├── logs\
echo   └── data\
echo.
echo 🚀 下一步:
echo   1. 根据项目类型选择合适的脚本运行
echo   2. 配置环境变量（如果需要）
echo   3. 开始编写代码！
echo.
echo 💡 提示:
echo   - 如果是 Python 项目，在 src/ 目录创建 main.py
echo   - 如果是 .NET 项目，在 src/ 目录创建项目文件
echo   - 运行 scripts\start.bat 启动应用