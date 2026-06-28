# 最终验收清单 v2.5.1

## 交付前文件检查

- [ ] `Run.bat` 存在。
- [ ] `install.ps1` 存在。
- [ ] `config.json` 存在且可解析。
- [ ] `update-config.json` 存在且可解析。
- [ ] `README.md` 已更新到 v2.5.1。
- [ ] `CHANGELOG.md` 存在并记录 v1.0 到 v2.5.1。
- [ ] `RELEASE_NOTES_v2.5.1.md` 存在。
- [ ] `docs/final-acceptance-checklist.md` 存在。
- [ ] `sources/allowlist.json` 存在。

## 目录检查

- [ ] `installers/` 存在。
- [ ] `downloads/latest/` 存在。
- [ ] `downloads/archive/` 存在。
- [ ] `backups/configs/` 存在。
- [ ] `backups/installers/` 存在。
- [ ] `reports/` 存在。
- [ ] `reports/update/` 存在。
- [ ] `logs/` 存在。
- [ ] `logs/update/` 存在。
- [ ] 不删除历史 `reports/`、`logs/`、`backups/`。

## installers 安装包检查

- [ ] `installers/cc-switch.msi` 文件名正确。
- [ ] `installers/codex.exe` 文件名正确。
- [ ] `installers/claude-desktop.exe` 文件名正确。
- [ ] `installers/openclaw.exe` 文件名正确。
- [ ] `installers/qianwen.exe` 文件名正确。
- [ ] `installers/TeleAgent.exe` 文件名正确。
- [ ] `installers/python-3.12.exe` 文件名正确。
- [ ] `installers/node-lts.msi` 文件名正确。
- [ ] `installers/clash.exe` 文件名正确。
- [ ] `installers/wechat.exe` 文件名正确。
- [ ] `installers/qq.exe` 文件名正确。
- [ ] `installers/todesk.exe` 文件名正确。
- [ ] `installers/zhipu-ime.exe` 文件名正确。
- [ ] 如需 Codex CLI，先在 `config.json` 中启用，再准备 `installers/codex-cli.exe`。

## 静态校验

- [ ] PowerShell 语法通过。
- [ ] `config.json` 可解析。
- [ ] `update-config.json` 可解析。
- [ ] `sources/allowlist.json` 可解析。

## 菜单检查

- [ ] 菜单显示为 v2.5.1。
- [ ] 菜单包含 `[1]` 到 `[12]`。
- [ ] `[12] 退出` 可正常退出。

## 只读/预览功能验收

- [ ] `[2] 仅检查电脑环境` 可生成 `reports/report_*.md` 和 `logs/install_*.log`。
- [ ] `[5] 检查可更新软件` 可生成 `reports/update/update_check_*.md` 和 `logs/update/update_check_*.log`。
- [ ] `[10] 安装位置策略预览` 可生成 `reports/install_location_preview_*.md` 和 `logs/install_location_preview_*.log`。
- [ ] `[11] 安装命令预演` 可生成 `reports/install_command_preview_*.md` 和 `logs/install_command_preview_*.log`。
- [ ] `[11]` 报告中 `cc-switch.msi` 使用 `msiexec /i` 预演。
- [ ] `[11]` 报告中 `node-lts.msi` 使用 `INSTALLDIR` 预演。
- [ ] `[11]` 报告中 `claude-desktop.exe` 可被识别。
- [ ] `[11]` 报告中 `codex.exe` 标记为在线引导器并建议人工确认。

## 会修改系统的功能验收

- [ ] `[1] 一键安装 / 升级所有软件` 会执行普通离线安装包，执行前必须人工确认风险。
- [ ] `[1]` 遇到 `installerKind=online_stub` 不会默认静默自动安装。
- [ ] `[4] 修复环境变量` 只刷新当前工具运行会话 PATH。
- [ ] `[8] 恢复软件配置` 恢复前会自动创建 `pre_restore` 备份。
- [ ] `[9] 安全升级模式` 当前只显示 OpenClaw。
- [ ] `[9]` 未输入大写 `YES` 时不会执行安装包。

## 下载与升级安全边界

- [ ] `[5]` 不下载、不安装、不升级。
- [ ] `[6]` 下载只写入 `downloads/latest/`，不安装、不升级、不复制到 `installers/`。
- [ ] `[6]` 下载使用 `.part` 临时文件。
- [ ] `[6]` 下载报告包含临时文件、大小匹配、半包清理、下载耗时。
- [ ] `[7]` 只备份配置，不修改原配置。
- [ ] `[9]` 升级前会创建 `pre_upgrade` 配置备份。
- [ ] `[9]` 不自动替换 `installers/`。
- [ ] 微信、QQ、ToDesk、Clash、智谱AI输入法不进入安全升级模式。

## Codex 桌面端专项检查

- [ ] `config.json` 中 Codex 桌面端 `installer` 为 `codex.exe`。
- [ ] `config.json` 中 Codex 桌面端 `installerKind` 为 `online_stub`。
- [ ] `offlineInstallSupported` 为 `false`。
- [ ] `requiresNetwork` 为 `true`。
- [ ] `requiresStoreInstaller` 为 `true`。
- [ ] `[11]` 报告提示不保证离线安装成功。

## U 盘交付检查

- [ ] 整个 `AI-Environment/` 文件夹可完整复制到 U 盘。
- [ ] U 盘中保留全部配置、安装包、文档和目录。
- [ ] 新电脑上从 `Run.bat` 启动。
- [ ] 首次运行建议先选 `[2] 仅检查电脑环境`。
- [ ] 执行安装或升级前，确认报告和日志路径可写。
