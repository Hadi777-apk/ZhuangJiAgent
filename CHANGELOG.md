# Changelog

## v2.5.3 - Git 支持

- 新增 Git 支持：
  - `config.json` 新增 `Git`。
  - `update-config.json` 新增 `Git`，策略为 `detect_only`。
  - 安装包使用 `installers/git.exe`。
  - 识别为 Git for Windows 离线安装包：`installerKind: offline_installer`。
  - 允许新电脑首次离线安装，但已安装时默认跳过，不自动升级。
- Git 检测规则：
  - `git --version`。
  - `versionCommand: git --version`。
  - 支持常见 `%ProgramFiles%\Git` 和 `%LOCALAPPDATA%\Programs\Git` 路径。
- Git 安装后处理：
  - 安装成功后刷新当前 PowerShell 会话 PATH。
  - 复检 `git --version`。
- 文档和验收清单同步更新到 v2.5.3。

## v2.5.2 - 新电脑实测稳定性修正

- Added Google Chrome offline MSI support:
  - `config.json` 中 Google Chrome 使用 `chrome.msi`。
  - `type: msi`，`installerKind: offline_installer`。
  - 支持新电脑首次离线安装，但已安装时默认跳过，不自动升级。
- Improved Claude Desktop detection:
  - 补充 `HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\AnthropicClaude`。
  - 补充 `%LOCALAPPDATA%\AnthropicClaude` 和 `%LOCALAPPDATA%\AnthropicClaude\claude.exe`。
- Changed ToDesk to manual confirmation:
  - `autoInstallEnabled: false`。
  - `requireManualConfirmBeforeInstall: true`。
  - 不再参与 `[1]` 自动静默安装。
- Changed Codex `online_stub` from failure to manual confirmation:
  - Codex 桌面端仍不是完整离线包。
  - 默认人工确认，不计入失败。
- Added manual confirmation count in reports:
  - 安装/升级汇总新增“人工确认”口径。

## v2.5.1 - 安装命令预演与封版整理

- 新增 `[11] 安装命令预演`，退出调整为 `[12]`。
- 安装命令预演只生成命令字符串，不执行 `exe` 或 `msiexec`。
- 报告 `reports/install_command_preview_*.md` 显示安装包存在性、类型、静默参数、自定义目录参数、预计命令和人工确认建议。
- 接入 Claude Desktop：
  - `config.json` 新增 `Claude Desktop`。
  - `update-config.json` 新增 `Claude Desktop`，默认只检测，不自动下载、不自动升级。
- 接入 Google Chrome：
  - `config.json` 新增 `Google Chrome`。
  - `update-config.json` 新增 `Google Chrome`，策略为 `detect_only`。
  - Chrome 安装包切换为 `chrome.msi` 官方企业版离线 MSI，支持未安装时按 MSI 静默安装；已安装时默认跳过，不自动升级。
- Codex 桌面端增加 `online_stub` 标记：
  - `installerKind: online_stub`
  - `offlineInstallSupported: false`
  - `requiresNetwork: true`
  - `requiresStoreInstaller: true`
  - `[1]` 默认不把它当作普通离线安装包静默自动安装。
  - `[11]` 报告提示它疑似在线引导安装器，不保证离线安装成功。

## v2.5 - 安装位置策略预览

- 新增 `[10] 安装位置策略预览`，退出调整为 `[11]`。
- `config.json` 新增全局 `installLocationPolicy`。
- 每个软件新增安装位置策略字段：
  - `supportCustomInstallDir`
  - `customInstallDir`
  - `installDirArgsTemplate`
  - `installLocationRisk`
  - `installLocationPolicy`
  - `installLocationNotes`
- 支持 C 盘/D 盘空间检查。
- 只生成安装位置预览报告，不安装、不移动软件、不创建 D 盘目录、不修改 PATH。

## v2.4.1 - 下载稳定性增强

- `[6] 下载最新版安装包` 改为 `.part` 临时文件下载。
- 下载完成后先校验大小，再重命名为正式文件。
- GitHub Release asset 提供 size 时，必须与实际下载大小一致。
- 下载失败、超时或大小不一致时清理半包。
- 下载报告新增临时文件、大小匹配、半包清理和下载耗时字段。
- `update-config.json` 新增 `downloadTimeoutMinutes`，默认 20 分钟。

## v2.4 - 安全升级模式

- 新增 `[9] 安全升级模式`。
- 当前只允许 OpenClaw 进入安全升级模式。
- 安全升级流程包括版本检测、目标包校验、配置备份、旧安装包备份、用户确认、安装执行、复检和报告。
- 版本相同或目标版本未知时需要 `FORCE`。
- 降级时需要 `DOWNGRADE`。
- 不自动替换 `installers/`，不自动恢复配置。

## v2.3 - 配置备份恢复

- 新增 `[7] 备份软件配置`。
- 新增 `[8] 恢复软件配置`。
- 当前真实验证对象为 OpenClaw。
- 配置备份写入 `backups/configs/OpenClaw/yyyyMMdd_HHmmss/`。
- 每次备份生成 `manifest.json`。
- 恢复前自动创建 `pre_restore_yyyyMMdd_HHmmss` 备份。
- 恢复只覆盖 manifest 中记录的文件。

## v2.2 - 隔离下载

- 新增 `[6] 下载最新版安装包`。
- 下载文件放入 `downloads/latest/软件名/`。
- 旧下载文件归档到 `downloads/archive/软件名/时间戳/`。
- 使用 `sources/allowlist.json` 控制下载域名白名单。
- 不安装、不升级、不复制到 `installers/`。
- OpenClaw 完成官方 GitHub Release 下载试点。

## v2.1 - 更新检查

- 新增 `[5] 检查可更新软件`。
- 新增 `update-config.json`。
- 支持只读更新检查报告和日志。
- 支持 `winget` 只读查询、GitHub Releases latest 查询、manual/official_page 降级记录。
- 不下载、不安装、不升级。

## v1.0 - 离线安装巡检

- 支持 `Run.bat` 启动和管理员权限提升。
- 支持 `config.json` 配置驱动的软件检测、安装、升级和跳过。
- 支持本地 `installers/` 离线安装包。
- 支持硬件巡检、环境报告和日志。
- 支持失败不中断，继续处理后续软件。
- 支持环境变量修复。
