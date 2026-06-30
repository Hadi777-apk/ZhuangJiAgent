# Release Notes v2.5.2

## 版本定位

v2.5.2 是基于新电脑实测后的稳定性修正版。它不引入新的安装模式，重点修正检测口径、人工确认口径和 Chrome 离线 MSI 接入后的交付说明。

## 本版修正

- Claude Desktop 检测规则补强：
  - 可识别 `HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\AnthropicClaude`。
  - 可识别 `%LOCALAPPDATA%\AnthropicClaude`。
  - 可识别 `%LOCALAPPDATA%\AnthropicClaude\claude.exe`。
- ToDesk 改为人工确认：
  - `autoInstallEnabled: false`。
  - `requireManualConfirmBeforeInstall: true`。
  - 不再参与 `[1]` 自动静默安装。
- Codex 桌面端 `online_stub` 状态口径修复：
  - 默认人工确认。
  - 不再计入失败。
  - `codex.exe` 仍不是完整离线包，可能需要联网或 Microsoft Store 组件。
- Google Chrome 官方企业版离线 MSI 接入：
  - `installer: chrome.msi`。
  - `type: msi`。
  - `installerKind: offline_installer`。
  - `offlineInstallSupported: true`。
  - `requiresNetwork: false`。
  - `autoInstallEnabled: true`。
  - 更新策略仍为 `detect_only`。
- 报告汇总增加“人工确认”口径。

## 当前能力

- Chrome 可用于新电脑首次离线安装。
- Chrome 已安装时默认跳过，不覆盖安装，不自动升级。
- Chrome 更新检查只检测，不自动下载，不自动升级。
- ToDesk 仍建议人工安装。
- Codex 桌面端仍需人工确认，不作为完整离线安装包处理。

## 建议运行顺序

1. `[2] 仅检查电脑环境`
2. `[11] 安装命令预演`
3. `[10] 安装位置策略预览`
4. 确认报告、安装包和风险提示后，再考虑 `[1] 一键安装 / 升级所有软件`

## 已验证内容

- PowerShell 语法可解析。
- `config.json` 可解析。
- `update-config.json` 可解析。
- `[2] 仅检查电脑环境` 可生成报告。
- `[11] 安装命令预演` 可生成报告。
- Google Chrome 预演命令为 `msiexec /i "installers\chrome.msi" /qn /norestart`。

## 已知限制

- 未在本次封版整理中执行安装、下载或升级。
- 安全升级模式目前仍只支持 OpenClaw。
- 安装位置策略目前仍只预览，不移动已安装软件，不自动创建 D 盘目录。
- 高风险软件默认只检测或人工确认，不自动升级。
