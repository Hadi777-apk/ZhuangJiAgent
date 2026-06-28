# AI 开发环境初始化工具 v2.5.1

这是一个面向 Windows 11 电脑的 U 盘环境初始化工具。它以 `Run.bat` 启动，主逻辑在 `install.ps1`，软件清单由 `config.json` 和 `update-config.json` 驱动。

当前版本支持环境巡检、本地安装包安装/升级、更新检查、隔离下载、配置备份/恢复、OpenClaw 安全升级试点、安装位置策略预览和安装命令预演。

## 目录说明

```text
AI-Environment/
├── Run.bat
├── install.ps1
├── config.json
├── update-config.json
├── installers/
├── downloads/
├── backups/
├── reports/
├── logs/
├── sources/
├── policies/
├── docs/
└── cache/
```

- `installers/`：本地安装包目录，供 `[1] 一键安装 / 升级所有软件` 使用。
- `downloads/latest/`：更新 Agent 下载的新安装包暂存区，不会自动复制到 `installers/`。
- `downloads/archive/`：旧下载文件归档目录。
- `backups/configs/`：软件配置备份目录。
- `backups/installers/`：安全升级前的旧安装包备份目录。
- `reports/`：普通巡检、安装位置预览、命令预演等报告。
- `reports/update/`：更新检查、下载、备份、恢复、安全升级报告。
- `logs/`：普通巡检、安装位置预览、命令预演日志。
- `logs/update/`：更新检查、下载、备份、恢复、安全升级日志。
- `sources/`：下载来源白名单等来源配置。
- `policies/`：策略相关文件预留目录。

不要删除已有的 `reports/`、`logs/`、`backups/`，这些目录用于审计和回溯。

## 菜单说明

```text
[1] 一键安装 / 升级所有软件
[2] 仅检查电脑环境
[3] 导出环境报告
[4] 修复环境变量
[5] 检查可更新软件
[6] 下载最新版安装包
[7] 备份软件配置
[8] 恢复软件配置
[9] 安全升级模式
[10] 安装位置策略预览
[11] 安装命令预演
[12] 退出
```

### [1] 一键安装 / 升级所有软件

读取 `config.json`，使用 `installers/` 中的本地安装包执行安装或升级。

这是会修改系统的功能：会执行安装包，可能写入程序目录、注册表、环境变量或桌面客户端配置。缺少安装包时会记录失败并继续处理后续软件。

`installerKind=online_stub` 的软件不会被当作普通离线安装包静默自动安装，会提示人工确认。

### [2] 仅检查电脑环境

只读巡检硬件、Windows、管理员权限、PowerShell、磁盘空间和软件安装状态。

这是只读功能，不安装、不升级、不下载。

### [3] 导出环境报告

导出最近一次环境检测或安装结果报告。如果当前没有检测结果，会先执行一次环境检测。

通常是只读功能。

### [4] 修复环境变量

刷新当前 PowerShell 会话中的 PATH，并补充常见 Node、Python、npm 路径。

它不执行安装包，但会影响当前工具运行会话中的环境变量。

### [5] 检查可更新软件

读取 `update-config.json`，只检查当前版本和可更新状态。

这是只读功能，不下载、不安装、不升级。`winget` 只用于只读查询，不执行 `winget upgrade`。

### [6] 下载最新版安装包

按 `update-config.json` 和 `sources/allowlist.json` 的白名单规则下载允许下载的软件安装包。

下载只写入 `downloads/latest/软件名/`，旧的 latest 文件会先归档到 `downloads/archive/软件名/时间戳/`。下载不会安装、不会升级、不会复制到 `installers/`。

v2.4.1 开始，下载先写入 `.part` 临时文件，大小校验通过后才重命名为正式文件。失败或超时会清理半包。

### [7] 备份软件配置

读取 `update-config.json` 中的 `configPaths`，对真实存在的配置目录做备份。

当前真实验证对象是 OpenClaw。备份写入 `backups/configs/` 并生成 `manifest.json`。

### [8] 恢复软件配置

列出历史配置备份，用户选择后显示恢复预览。

这是会修改用户配置的功能。恢复前会自动创建 `pre_restore_yyyyMMdd_HHmmss` 备份，只有输入大写 `YES` 才会恢复。

### [9] 安全升级模式

当前只支持 OpenClaw。

流程包括当前版本检测、目标安装包校验、配置备份、旧安装包备份、用户确认、安装执行、复检和报告。只有输入大写 `YES` 才会执行安装包。

安全升级模式不会自动替换 `installers/` 中的安装包，也不会自动恢复配置。

### [10] 安装位置策略预览

读取 `config.json` 的安装位置策略，检查 C 盘/D 盘空间，预览每个软件的新装建议目录、风险和备注。

这是只读预览功能，不安装、不升级、不移动已安装软件、不创建 `D:\AI-Environment-Apps`、不修改 PATH。

### [11] 安装命令预演

读取 `config.json` 和 `installers/`，预览未来安装时可能使用的命令。

这是只读预演功能，只生成命令字符串和报告，不执行 `exe`、不执行 `msiexec`、不安装、不升级、不修改系统。

### [12] 退出

退出工具。

## installers 放置规则

`installers/` 是离线安装/升级模式 `[1]` 使用的本地安装包目录。文件名必须和 `config.json` 中对应软件的 `installer` 字段一致。

当前常用文件名包括：

```text
cc-switch.msi
codex.exe
claude-desktop.exe
openclaw.exe
qianwen.exe
TeleAgent.exe
python-3.12.exe
node-lts.msi
clash.exe
wechat.exe
qq.exe
todesk.exe
zhipu-ime.exe
```

说明：

- `NPM` 不需要单独安装包，它随 Node 安装，但工具会单独检测 `npm -v`。
- `Codex CLI` 当前默认 `enabled:false`，如需启用，请修改 `config.json` 并准备 `codex-cli.exe`。
- `Codex 桌面端` 当前的 `codex.exe` 被标记为 `online_stub`，是 Microsoft Store Installer 引导器，不视为完整离线安装包，不保证离线安装成功。

## downloads 与 installers 的区别

| 目录 | 用途 | 是否自动执行 | 是否会被 [1] 使用 |
| --- | --- | --- | --- |
| `installers/` | 离线安装/升级包 | `[1]` 会执行普通离线包 | 是 |
| `downloads/latest/` | 新下载安装包暂存区 | `[6]` 不执行；`[9]` 仅 OpenClaw 在确认后执行 | 否 |
| `downloads/archive/` | 旧下载文件归档 | 不执行 | 否 |

工具不会把 `downloads/latest/` 的文件自动复制到 `installers/`。

## 哪些功能会修改系统

只读或预览功能：

- `[2] 仅检查电脑环境`
- `[3] 导出环境报告`
- `[5] 检查可更新软件`
- `[10] 安装位置策略预览`
- `[11] 安装命令预演`
- `[6] 下载最新版安装包` 不安装、不升级，但会写入工具目录下的 `downloads/`
- `[7] 备份软件配置` 不修改原配置，但会写入工具目录下的 `backups/`

可能修改系统或用户配置的功能：

- `[1] 一键安装 / 升级所有软件`：会执行 `installers/` 中的普通离线安装包
- `[4] 修复环境变量`：会刷新当前 PowerShell 会话 PATH
- `[8] 恢复软件配置`：会覆盖 manifest 记录过的配置文件
- `[9] 安全升级模式`：在确认后会执行 OpenClaw 安装包

## 重要限制

- 安全升级目前只支持 OpenClaw。
- 安装位置策略目前只是预览和命令预演，不会自动安装到 D 盘。
- 高风险软件如微信、QQ、ToDesk、Clash、智谱AI输入法默认不自动下载、不自动升级。
- Codex 桌面端 `codex.exe` 是 Store Installer 在线引导器，可能需要联网和 Microsoft Store 组件，不保证离线安装成功。

## U 盘迁移方式

1. 将整个 `AI-Environment` 文件夹复制到 U 盘。
2. 确认 `installers/` 中已有需要离线安装的软件包。
3. 保留 `config.json`、`update-config.json`、`sources/allowlist.json`。
4. 到新电脑后双击 `Run.bat`。
5. 在管理员权限弹窗中选择“是”。
6. 优先选择 `[2] 仅检查电脑环境` 生成基线报告。
7. 确认报告无误后再使用 `[1]` 或其他会修改系统的功能。

## 安全原则

- 不从非官方来源下载软件。
- 下载和安装分离。
- `installers/` 不会被自动覆盖。
- 高风险软件默认只检测，不自动升级。
- 所有关键动作都会写入报告和日志。
