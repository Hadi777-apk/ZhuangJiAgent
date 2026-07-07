# Release Notes v2.5.1

## 当前版本能力

- 支持 Windows 11 环境巡检、硬件信息采集和 Markdown 报告。
- 支持基于 `config.json` 的本地安装包检测、安装、升级和跳过。
- 支持基于 `update-config.json` 的只读更新检查。
- 支持隔离下载到 `downloads/latest/`，不自动覆盖 `installers/`。
- 支持 OpenClaw 配置备份、恢复预览和安全升级试点。
- 支持安装位置策略预览，检查 C 盘/D 盘空间和建议安装目录。
- 支持安装命令预演，展示未来可能执行的安装命令。
- 支持 Claude Desktop 检测和本地安装包预演。
- 支持 Codex 桌面端在线引导器识别。

## 已验证内容

- PowerShell 语法可解析。
- `config.json` 可解析。
- `update-config.json` 可解析。
- 菜单显示 `[1]` 到 `[12]`。
- `[2] 仅检查电脑环境` 可生成普通报告。
- `[5] 检查可更新软件` 可生成更新检查报告。
- `[10] 安装位置策略预览` 可生成安装位置预览报告。
- `[11] 安装命令预演` 可生成安装命令预演报告。
- `cc-switch.msi` 作为 MSI 安装包可被命令预演识别。
- `node-lts.msi` 可被命令预演识别，并预演 `INSTALLDIR` 参数。
- `claude-desktop.exe` 可被命令预演识别。
- `codex.exe` 可被识别为安装包存在，但已标记为在线引导器。

## 未验证内容

- 未执行全量 `[1] 一键安装 / 升级所有软件` 的真实安装。
- 未执行 Codex 桌面端安装。
- 未执行 Claude Desktop 安装。
- 未执行微信、QQ、ToDesk、Clash、智谱AI输入法的真实安装。
- 未验证所有第三方安装器的静默参数一定有效。
- 未验证非 OpenClaw 软件的安全升级。

## 已知限制

- 安全升级模式目前只支持 OpenClaw。
- 安装位置策略目前只预览，不自动安装到 D 盘。
- 安装命令预演只生成字符串，不代表安装器一定接受该参数。
- Codex 桌面端 `codex.exe` 是 Microsoft Store Installer 在线引导器，不是完整离线包，可能需要联网和 Microsoft Store 组件。
- Codex 桌面端被标记为 `installerKind=online_stub`，不会被 `[1]` 当作普通离线安装包静默自动执行。
- 高风险软件默认只检测，不自动下载、不自动升级。

## 使用注意事项

- 首次在新电脑运行时，建议先选择 `[2] 仅检查电脑环境`。
- 执行 `[1]` 前先查看 `[11] 安装命令预演` 报告。
- 如 C 盘空间紧张，先查看 `[10] 安装位置策略预览`，再人工决定是否使用 D 盘。
- 不要把 `downloads/latest/` 当作正式离线安装包目录；正式安装包应放在 `installers/`。
- 不要删除已有 `reports/`、`logs/`、`backups/`，这些文件用于回溯。
- Codex 桌面端当前不保证离线安装成功，应人工确认网络和 Microsoft Store 组件状态。
