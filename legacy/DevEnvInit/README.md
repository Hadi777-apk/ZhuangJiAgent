# DevEnvInit（历史归档）

本目录是 **DevEnvInit** 项目的完整历史归档，源自原 `Hadi777-apk/WPF-UI` 仓库。

## 与 ZhuangJiAgent 的关系

DevEnvInit 与 ZhuangJiAgent 是**同一项目的两次迭代**：

- **DevEnvInit（v1 ~ v2.5.3，2026-06 ~ 07）** — PowerShell 驱动的 U 盘环境初始化工具，`install.ps1` + `config.json`，附多项目 WPF 前端（DevEnvInit.App / Core / Services）与单元测试。
- **ZhuangJiAgent（v1.0.0，2026-07）** — 完全重写为单项目 WPF + manifest 驱动的 Windows 软件批量部署工具，在线优先、离线降级架构。

合并工作树以 **ZhuangJiAgent 为准**（仓库根目录与 `src/ZhuangJiAgent/`）。DevEnvInit 的全部源码、测试、配置、脚本与发布说明在此目录下原地保留，仅作历史归档，不参与主构建。

## 目录

- `src/DevEnvInit.{App,Core,Services}/` — 多项目 WPF 源码
- `src/DevEnvInit.sln` — DevEnvInit 解决方案
- `tests/` — xUnit 测试项目
- `install.ps1` / `gui.ps1` / `Run*.bat` — 主逻辑与启动入口
- `config.json` / `update-config.json` / `sources/allowlist.json` — 清单与来源配置
- `RELEASE_NOTES_v2.5.*.md` / `CHANGELOG.md` — 发布历史

## 构建

可选，仅用于查阅或复现历史版本：

```bash
cd legacy/DevEnvInit
dotnet build src/DevEnvInit.sln
dotnet test tests/DevEnvInit.Services.Tests/DevEnvInit.Services.Tests.csproj
```

如需运行 install.ps1，请参考仓库根目录的脚手架脚本约定（本项目不再主动维护 DevEnvInit）。