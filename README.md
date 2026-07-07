# 装机 Agent

<div align="center">

**Windows 软件批量部署工具 · 在线优先、离线降级 · 开箱即用**

[![.NET Version](https://img.shields.io/badge/.NET-9.0-512BD4)](https://dotnet.microsoft.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Windows-0078D4)](https://www.microsoft.com/windows)

[功能特性](#功能特性) • [快速开始](#快速开始) • [使用指南](#使用指南) • [文档](#文档) • [贡献](#贡献)

</div>

---

## 📖 项目简介

**装机 Agent** 是一个现代化的 Windows 软件批量部署工具，采用 **在线优先、离线降级** 架构，支持清单驱动的差异化同步和自动更新机制。非常适合：

- 🖥️ **新机装机** — 一键安装常用软件
- 🔄 **软件更新** — 自动检查和批量更新
- 🏢 **企业部署** — 内网私有化清单部署
- 🎒 **便携工具** — 离线环境照常使用

> **历史归档**：本仓库由 `WPF-UI`（DevEnvInit，PowerShell + 多项目 WPF）与 `ZhuangJiAgent`（单项目 WPF + manifest 驱动）两个仓库合并而来。DevEnvInit 的完整源码、测试与发布说明保留在 [`legacy/DevEnvInit/`](legacy/DevEnvInit/)，仅作历史可追溯，不参与主构建。当前工作树以 ZhuangJiAgent 为准。

---

## ✨ 功能特性

### 核心功能

- ✅ **在线优先、离线降级** — 3 秒网络检测，自动切换本地缓存
- ✅ **清单驱动差异化同步** — 仅下载变更的软件包
- ✅ **并行下载 + 断点续传** — 最多 3 并发，支持 HTTP Range
- ✅ **SHA256 双重校验** — 下载后 + 安装前二次验证
- ✅ **多种安装器支持** — Exe / MSI / MSIX / Winget
- ✅ **智能软件检测** — Registry / File / Command 三种方式
- ✅ **实时进度显示** — 可视化进度条 + 速度统计

### UI 特性

- 🎨 **现代化 WPF 界面** — 卡片式布局，美观易用
- 🔍 **搜索和过滤** — 实时搜索 + 分类筛选
- ⚙️ **完整设置页面** — 强制离线模式、自定义下载目录
- 📊 **状态实时更新** — 每个软件包独立显示进度
- 🎯 **批量操作** — 全选/取消全选，一键安装

### 安全特性

- 🔒 **哈希校验** — 防止文件损坏和中间人攻击
- 💾 **磁盘空间检查** — 下载前验证可用空间
- 🔄 **原子文件操作** — 临时文件 + 替换，保证完整性
- 🚫 **异常处理** — 友好的错误提示和恢复机制

---

## 🚀 快速开始

### 系统要求

- **操作系统：** Windows 10/11（x64）
- **运行时：** .NET 9 Desktop Runtime
- **磁盘空间：** 至少 1 GB 可用空间

### 安装 .NET 9 Runtime

如果尚未安装，请下载并安装 [.NET 9 Desktop Runtime](https://dotnet.microsoft.com/download/dotnet/9.0)。

### 下载和运行

#### 方式 1：从 Release 下载（推荐）

1. 前往 [Releases](https://github.com/yourusername/ZhuangJiAgent/releases) 页面
2. 下载最新版本的 `ZhuangJiAgent-vX.X.X.zip`
3. 解压到任意目录
4. 运行 `ZhuangJiAgent.exe`

#### 方式 2：从源码编译

```bash
# 克隆仓库
git clone https://github.com/yourusername/ZhuangJiAgent.git
cd ZhuangJiAgent

# 编译项目
cd src
dotnet build -c Release

# 运行
cd ZhuangJiAgent/bin/Release/net9.0-windows
./ZhuangJiAgent.exe
```

---

## 📘 使用指南

### 第一次启动

1. **自动加载清单** — 程序启动后自动加载软件清单
2. **网络检测** — 3 秒内完成在线/离线判断
3. **后台检查更新** — 如果在线，后台静默检查更新

### 安装软件

1. **浏览软件包** — 查看所有可用软件（卡片式展示）
2. **勾选需要的软件** — 支持全选/搜索/分类过滤
3. **点击"安装选中"** — 自动下载 + 按顺序安装
4. **查看实时进度** — 每个软件卡片显示下载速度和安装状态

### 检查和应用更新

1. **点击"检查更新"** — 与远程清单比对版本
2. **查看更新详情** — 显示有更新的软件包数量和总大小
3. **点击"应用更新"** — 自动下载并更新本地清单

### 配置设置

点击右上角 **⚙ 设置** 按钮：

- **强制离线模式** — 完全不连接网络
- **下载目录** — 自定义软件包缓存位置
- **并发下载数** — 1-5 可调（默认 3）
- **启动时自动检查更新** — 后台静默检查开关
- **远程清单 URL** — 自定义清单源

---

## 📚 文档

### 架构文档

- **[PROJECT_SUMMARY.md](PROJECT_SUMMARY.md)** — 项目架构和实施总结
- **[FEATURE_COMPLETION.md](FEATURE_COMPLETION.md)** — 功能完善总结
- **[TESTING_GUIDE.md](TESTING_GUIDE.md)** — 功能测试指南

### 清单格式

- **[manifest-schema.json](docs/manifest-schema.json)** — JSON Schema（draft-07）
- **[示例清单](samples/manifest.json)** — 包含 5 个常见软件包

### 清单字段说明

```json
{
  "version": "1.0",
  "lastUpdated": "2026-07-06T12:00:00Z",
  "packages": [
    {
      "id": "7zip",
      "name": "7-Zip",
      "version": "24.08",
      "category": "Utility",
      "publisher": "Igor Pavlov",
      "description": "开源高压缩比文件压缩工具",
      "order": 1,
      "defaultSelected": true,
      "installer": {
        "type": "exe",
        "url": "https://www.7-zip.org/a/7z2408-x64.exe",
        "hash": "实际的SHA256哈希值",
        "size": 1702400,
        "silentArgs": "/S"
      },
      "detection": {
        "type": "registry",
        "registryKey": "HKEY_LOCAL_MACHINE\\SOFTWARE\\7-Zip",
        "registryValue": "Path"
      }
    }
  ]
}
```

---

## 🛠️ 开发

### 技术栈

- **.NET 9** — 最新 LTS 运行时
- **WPF** — Windows Presentation Foundation
- **MVVM** — Model-View-ViewModel 架构
- **DI 容器** — Microsoft.Extensions.Hosting
- **语义化版本** — Semver 库

### 项目结构

```
src/ZhuangJiAgent/
├── Models/             # 数据模型（9 个）
├── Services/           # 业务逻辑（14 个接口+实现）
├── ViewModels/         # 视图模型（4 个）
├── Converters/         # XAML 转换器
├── App.xaml            # 应用程序入口
├── MainWindow.xaml     # 主窗口
└── SettingsWindow.xaml # 设置窗口
```

### 编译要求

- **.NET 9 SDK**
- **Visual Studio 2022** 或 **Rider**

### 本地开发

```bash
# 克隆仓库
git clone https://github.com/yourusername/ZhuangJiAgent.git
cd ZhuangJiAgent/src

# 还原依赖
dotnet restore

# 编译
dotnet build

# 运行
dotnet run --project ZhuangJiAgent
```

---

## 🤝 贡献

欢迎贡献！请参阅 [CONTRIBUTING.md](CONTRIBUTING.md) 了解贡献指南。

### 贡献方式

1. **报告 Bug** — 通过 [Issues](https://github.com/yourusername/ZhuangJiAgent/issues) 报告
2. **功能建议** — 提交新功能的 Issue
3. **提交软件包** — 贡献新的软件包到清单
4. **代码贡献** — Fork 项目并提交 Pull Request

### 添加软件包

参见 [CONTRIBUTING.md](CONTRIBUTING.md) 中的"添加软件包"章节。

---

## 📄 许可证

本项目基于 **MIT License** 开源。详见 [LICENSE](LICENSE) 文件。

---

## 🙏 致谢

- **[Semver](https://github.com/maxhauser/semver)** — 语义化版本解析
- **Microsoft** — .NET 和 WPF 框架
- **社区贡献者** — 感谢所有贡献者

---

## 📧 联系方式

- **Issue 追踪：** [GitHub Issues](https://github.com/yourusername/ZhuangJiAgent/issues)
- **讨论区：** [GitHub Discussions](https://github.com/yourusername/ZhuangJiAgent/discussions)

---

<div align="center">

**⭐ 如果这个项目对您有帮助，请点个 Star！**

Made with ❤️ by [Your Name](https://github.com/yourusername)

</div>
