# Release Notes v2.5.3

## 版本定位

v2.5.3 是在 v2.5.2 稳定性修正版基础上的小版本更新，新增 Git for Windows 支持。它不改变已有安装流程，不开放自动下载或自动升级。

## 本版新增

- 新增 Git 支持：
  - 安装包文件名：`git.exe`。
  - 安装包类型：`exe`。
  - `installerKind: offline_installer`。
  - `offlineInstallSupported: true`。
  - `requiresNetwork: false`。
- Git 允许新电脑首次离线安装。
- Git 已安装时默认跳过，不覆盖安装，不自动升级。
- Git 更新策略为 `detect_only`，不自动下载，不自动升级。
- Git 安装后会刷新当前 PowerShell 会话 PATH，并复检 `git --version`。

## 当前保留策略

- Chrome 仍使用 `chrome.msi` 官方企业版离线安装包。
- Chrome 可用于新电脑首次离线安装，但默认不自动升级。
- Codex 桌面端仍是 `online_stub`，不是完整离线包，默认人工确认。
- ToDesk 仍为人工确认，不参与 `[1]` 自动静默安装。

## 建议运行顺序

1. `[2] 仅检查电脑环境`
2. `[11] 安装命令预演`
3. `[10] 安装位置策略预览`
4. 确认报告、安装包和风险提示后，再考虑 `[1] 一键安装 / 升级所有软件`

## 已验证内容

- PowerShell 语法可解析。
- `config.json` 可解析。
- `update-config.json` 可解析。
- `[2] 仅检查电脑环境` 可生成报告并显示 Git 状态。
- `[5] 检查可更新软件` 可生成报告并显示 Git，策略为 `detect_only`。
- `[11] 安装命令预演` 可生成报告并显示 Git 预演命令。
- Git 预演命令为 `"installers\git.exe" /VERYSILENT /NORESTART /NOCANCEL /SP-`。

## 已知限制

- 本次未执行 Git 安装包。
- 本次未执行安装、下载或升级。
- Git 静默参数来自 Git for Windows 常见安装器参数，真实批量安装前仍建议先在测试机验证。
- 安全升级模式目前仍只支持 OpenClaw。
