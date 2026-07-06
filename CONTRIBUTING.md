# 贡献指南

感谢您对装机 Agent 项目的关注！我们欢迎各种形式的贡献。

---

## 🤝 如何贡献

### 报告 Bug

如果您发现了 Bug，请通过 [GitHub Issues](https://github.com/yourusername/ZhuangJiAgent/issues) 报告：

1. 检查是否已有相同的 Issue
2. 使用清晰的标题描述问题
3. 提供详细的重现步骤
4. 附上截图或错误日志
5. 说明您的环境（Windows 版本、.NET 版本）

**Bug 报告模板：**

```markdown
**描述**
简要描述 Bug 的现象

**重现步骤**
1. 启动程序
2. 点击"安装选中"
3. 观察到错误

**预期行为**
应该正常下载并安装

**实际行为**
弹出错误提示："下载失败"

**环境**
- 操作系统：Windows 11 Pro 23H2
- .NET 版本：9.0.0
- 程序版本：v1.0.0

**截图**
（如有）
```

---

## 💡 功能建议

我们欢迎新功能的建议！请通过 Issue 提交：

1. 清晰描述功能需求
2. 说明使用场景和动机
3. 如果可能，提供 UI 设计或实现思路

---

## 📦 添加软件包

这是最简单的贡献方式！只需 3 步：

### 1. Fork 项目

点击 GitHub 页面右上角的 "Fork" 按钮。

### 2. 编辑 manifest.json

在 `samples/manifest.json` 中添加新的软件包：

```json
{
  "id": "your-software-id",
  "name": "软件名称",
  "version": "1.0.0",
  "category": "分类（如 Development, Utility, Browser）",
  "publisher": "发布者",
  "description": "简短描述（不超过 100 字）",
  "order": 100,
  "defaultSelected": false,
  "installer": {
    "type": "exe",
    "url": "https://example.com/installer.exe",
    "hash": "SHA256哈希值（小写）",
    "size": 文件大小（字节）,
    "silentArgs": "/S"
  },
  "detection": {
    "type": "registry",
    "registryKey": "HKEY_LOCAL_MACHINE\\SOFTWARE\\YourSoftware",
    "registryValue": "Version"
  }
}
```

### 3. 提交 Pull Request

1. 提交到您的 Fork 仓库
2. 创建 Pull Request
3. 标题格式：`[Package] 添加 软件名称`
4. 描述中说明软件用途

### 计算 SHA256 哈希

**PowerShell：**
```powershell
Get-FileHash -Path "installer.exe" -Algorithm SHA256 | Select-Object Hash
```

**Linux/macOS：**
```bash
sha256sum installer.exe
```

---

## 🔧 代码贡献

### 开发环境

1. **安装 .NET 9 SDK**
   - 下载：https://dotnet.microsoft.com/download/dotnet/9.0

2. **克隆您 Fork 的仓库**
   ```bash
   git clone https://github.com/yourusername/ZhuangJiAgent.git
   cd ZhuangJiAgent
   ```

3. **创建功能分支**
   ```bash
   git checkout -b feature/your-feature-name
   ```

4. **还原依赖并编译**
   ```bash
   cd src
   dotnet restore
   dotnet build
   ```

### 代码规范

- **命名约定**
  - 类名：PascalCase（如 `NetworkDetector`）
  - 方法名：PascalCase（如 `CheckForUpdatesAsync`）
  - 私有字段：_camelCase（如 `_httpClient`）
  - 参数/局部变量：camelCase（如 `packageId`）

- **异步方法**
  - 必须以 `Async` 结尾
  - 返回 `Task` 或 `Task<T>`
  - 接受 `CancellationToken` 参数

- **注释**
  - 公共 API 必须有 XML 文档注释
  - 复杂逻辑添加行内注释说明
  - 避免无意义的注释

- **MVVM 模式**
  - ViewModels 不应引用 Views
  - ViewModels 通过接口依赖 Services
  - 数据绑定优先于代码后置

### 提交规范

使用语义化提交信息：

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Type：**
- `feat`: 新功能
- `fix`: Bug 修复
- `docs`: 文档更新
- `style`: 代码格式（不影响功能）
- `refactor`: 重构
- `test`: 测试相关
- `chore`: 构建/工具链相关

**示例：**
```
feat(download): 添加断点续传支持

实现了 HTTP Range 请求，支持从上次中断位置继续下载。

Closes #42
```

### Pull Request 流程

1. **确保代码编译通过**
   ```bash
   dotnet build
   ```

2. **运行测试（如果有）**
   ```bash
   dotnet test
   ```

3. **提交到您的 Fork**
   ```bash
   git push origin feature/your-feature-name
   ```

4. **创建 Pull Request**
   - 标题简明扼要
   - 描述中说明：
     - 解决的问题
     - 实现方案
     - 测试方法
     - 相关 Issue

5. **等待 Review**
   - 维护者可能会提出修改建议
   - 及时响应并更新代码

---

## 📋 项目结构

```
ZhuangJiAgent/
├── src/
│   └── ZhuangJiAgent/
│       ├── Models/              # 数据模型
│       ├── Services/            # 业务逻辑
│       │   ├── IXxxService.cs   # 接口定义
│       │   └── XxxService.cs    # 实现
│       ├── ViewModels/          # 视图模型
│       ├── Converters/          # XAML 转换器
│       ├── App.xaml             # 应用程序入口
│       └── MainWindow.xaml      # 主窗口
├── docs/                        # 文档
├── samples/                     # 示例文件
└── tests/                       # 单元测试（待实现）
```

---

## 🧪 测试指南

### 手动测试

参见 [TESTING_GUIDE.md](TESTING_GUIDE.md)。

### 单元测试（计划中）

我们计划使用 xUnit 编写单元测试：

```bash
dotnet test
```

**测试覆盖重点：**
- Service 层业务逻辑
- 数据模型验证
- 网络检测逻辑
- 哈希校验功能

---

## 🎨 UI/UX 贡献

如果您擅长设计，欢迎：

1. **提交设计稿** — 通过 Issue 附上 Figma/Sketch 文件
2. **改进现有 UI** — 优化布局、颜色、图标
3. **国际化** — 添加多语言支持

---

## 📚 文档贡献

文档同样重要！您可以：

1. **完善 README** — 添加更多使用场景
2. **编写教程** — 如何部署私有清单服务器
3. **翻译文档** — 英文版 README
4. **API 文档** — 为公共接口补充文档

---

## 🚫 行为准则

本项目遵循 [Contributor Covenant 行为准则](https://www.contributor-covenant.org/)。

简而言之：

- ✅ 尊重他人，保持友善
- ✅ 建设性的讨论和反馈
- ✅ 关注问题本身，而非个人
- ❌ 禁止骚扰、歧视、侮辱性言论

---

## 📧 联系方式

如有疑问，可以通过以下方式联系：

- **Issue 讨论：** [GitHub Issues](https://github.com/yourusername/ZhuangJiAgent/issues)
- **功能讨论：** [GitHub Discussions](https://github.com/yourusername/ZhuangJiAgent/discussions)

---

## 🎖️ 贡献者

感谢所有贡献者！

您的贡献将被记录在项目的 [Contributors](https://github.com/yourusername/ZhuangJiAgent/graphs/contributors) 页面。

---

**再次感谢您的贡献！每一份贡献都让装机 Agent 变得更好。** 🎉
