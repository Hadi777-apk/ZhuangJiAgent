# 装机 Agent - 开发经验总结

## 项目背景

**目标：** 开发一个 Windows 软件批量部署工具  
**技术栈：** .NET 9 + WPF + MVVM  
**开发周期：** 完整实现（12 个阶段）

---

## 架构决策

### 1. 在线优先、离线降级架构

**问题：** 用户可能在有网或无网环境使用工具

**决策：** 采用"在线优先、离线降级"策略
- 启动时 3 秒网络检测
- 在线：拉取远程清单 + 后台更新
- 离线：使用本地缓存清单

**实现：**
- `NetworkDetector` — 并行探测 3 个端点（msftconnecttest + Cloudflare + Baidu）
- `SourceResolver` — 编排在线/离线切换逻辑

**经验：**
- 网络检测不要超过 3 秒，影响启动体验
- 离线模式必须完全可用，不能降级到"无法使用"

---

### 2. 清单驱动差异化同步

**问题：** 每次更新都下载全部软件包太浪费

**决策：** 清单驱动 + SemVer 版本比较
- 本地清单和远程清单做 diff
- 仅下载有变化的软件包
- 使用语义化版本号比较（`Semver` 库）

**实现：**
- `ManifestService.ComputeDiff()` — 计算差异
- 以 `package.Id` 为 key 做字典对比
- 比较 `SemVersion` 对象

**经验：**
- 必须原子更新本地清单（先写临时文件再替换）
- 清单必须包含 `lastUpdated` 时间戳

---

### 3. MVVM 严格分离

**问题：** WPF 项目容易把业务逻辑写在代码后置

**决策：** 严格 MVVM 架构
- ViewModel 不引用 View
- View 通过数据绑定与 ViewModel 交互
- 业务逻辑全部在 Service 层

**实现：**
- `ViewModelBase` — 实现 `INotifyPropertyChanged`
- `RelayCommand` — 简单命令实现
- DI 容器注入所有依赖

**经验：**
- ViewModel 中的异步方法使用 `RelayCommand` 包装
- 避免在 ViewModel 中直接操作文件或网络
- 所有 UI 状态通过属性绑定，不要在代码后置中设置

---

## 关键技术问题

### 1. 下载进度实时更新

**问题：** 如何在下载时实时更新 UI 进度条？

**解决方案：**
- 使用 `IProgress<T>` 接口
- 下载服务每 500ms 报告一次进度
- ViewModel 在进度回调中更新属性

**代码示例：**
```csharp
var progress = new Progress<DownloadProgress>(p => {
    vm.ProgressPercentage = p.ProgressPercentage;
    vm.StatusMessage = $"下载中 {p.ProgressPercentage:F1}%";
});
await _downloadService.DownloadAsync(url, path, progress);
```

**经验：**
- 不要每次收到字节都报告，会卡 UI
- 使用 `Stopwatch` 控制报告频率
- 进度回调在 UI 线程执行，不要做耗时操作

---

### 2. 并发下载控制

**问题：** 同时下载太多文件会占满带宽

**解决方案：**
- 使用 `SemaphoreSlim` 控制并发数
- 默认 3 并发，可在设置中调整

**代码示例：**
```csharp
private readonly SemaphoreSlim _semaphore = new(3);

await _semaphore.WaitAsync();
try {
    await DownloadFileAsync(url, path);
} finally {
    _semaphore.Release();
}
```

**经验：**
- 不要用 `Task.WhenAll` 直接启动所有下载
- 并发数 3-5 最佳，太多反而慢
- 记得在 finally 中 Release

---

### 3. SHA256 校验性能优化

**问题：** 下载 1GB 文件后再计算哈希太慢

**解决方案：**
- 下载过程中增量计算哈希
- 使用 `IncrementalHash` 类

**代码示例：**
```csharp
using var hash = IncrementalHash.CreateHash(HashAlgorithmName.SHA256);
while ((bytesRead = await stream.ReadAsync(buffer)) > 0) {
    await fileStream.WriteAsync(buffer, 0, bytesRead);
    hash.AppendData(buffer, 0, bytesRead);
}
var computedHash = hash.GetHashAndReset();
```

**经验：**
- 不要等下载完再计算哈希
- `IncrementalHash` 线程不安全，每个下载任务独立实例
- 哈希值转字符串用 `BitConverter.ToString().Replace("-", "")`

---

### 4. WPF 搜索和过滤

**问题：** 如何高效实现软件包搜索和分类过滤？

**解决方案：**
- 使用 `CollectionViewSource`
- 实现 `Filter` 委托

**代码示例：**
```csharp
PackagesView = CollectionViewSource.GetDefaultView(Packages);
PackagesView.Filter = FilterPackage;

private bool FilterPackage(object obj) {
    if (obj is not PackageViewModel package) return false;
    
    // 分类过滤
    if (SelectedCategory != "全部" && package.Category != SelectedCategory)
        return false;
    
    // 搜索过滤
    if (!string.IsNullOrWhiteSpace(SearchText)) {
        var search = SearchText.ToLowerInvariant();
        return package.DisplayName.ToLowerInvariant().Contains(search);
    }
    
    return true;
}
```

**经验：**
- 属性变化时调用 `PackagesView.Refresh()`
- 绑定到 `PackagesView` 而不是 `Packages`
- 大列表（1000+）考虑虚拟化

---

### 5. 异步方法的警告处理

**问题：** `async` 方法中没有 `await` 会警告

**解决方案：**
- 如果确实不需要异步，添加 `await Task.CompletedTask`
- 或者移除 `async` 关键字

**代码示例：**
```csharp
// 方式 1：添加 await
private async Task ShowDialogAsync() {
    await Task.CompletedTask;
    MessageBox.Show("Hello");
}

// 方式 2：返回 Task（不推荐）
private Task ShowDialogAsync() {
    MessageBox.Show("Hello");
    return Task.CompletedTask;
}
```

**经验：**
- 优先使用方式 1，保持方法签名一致
- 如果方法会被异步调用，保留 `async`

---

## 安全问题和解决方案

### 1. 下载文件校验

**问题：** 下载的文件可能被篡改

**解决方案：**
- 下载后立即 SHA256 校验
- 安装前再次校验（防止位翻转）
- 校验失败自动删除文件

**代码位置：**
- `DownloadService.DownloadPackageAsync()` — 下载后校验
- `UpdateService.ApplyUpdatesAsync()` — 安装前二次校验

**经验：**
- 哈希值必须小写存储
- 使用 `string.Equals(..., StringComparison.OrdinalIgnoreCase)` 比较
- 不匹配立即删除，不要留在磁盘

---

### 2. 磁盘空间检查

**问题：** 下载到一半磁盘满了

**解决方案：**
- 下载前计算所有文件总大小
- 检查目标磁盘可用空间
- 不足时提前拒绝

**代码示例：**
```csharp
var totalSize = packages.Sum(p => p.Installer.Size);
var driveInfo = new DriveInfo(Path.GetPathRoot(downloadDir));
if (driveInfo.AvailableFreeSpace < totalSize) {
    throw new InvalidOperationException("磁盘空间不足");
}
```

**经验：**
- 预留 10% 缓冲空间
- 检查目标磁盘，不是系统盘
- 失败时清理已下载的部分文件

---

### 3. Winget 退出码处理

**问题：** Winget 安装成功返回 3010（需要重启）

**解决方案：**
- 将 3010 视为成功
- 标记 `RequiresReboot = true`

**代码示例：**
```csharp
if (exitCode == 0 || exitCode == 3010) {
    return new InstallResult {
        Status = InstallStatus.Success,
        RequiresReboot = exitCode == 3010
    };
}
```

**经验：**
- MSI 也可能返回 3010
- UI 显示"需要重启"提示
- 不要强制重启用户电脑

---

## 常见错误和避免方法

### 1. Git 提交敏感文件

**问题：** `git add .` 可能误提交 .env、密钥

**解决方案：**
- 永远不用 `git add .`
- 使用 `git add <具体文件>`
- 配置完善的 .gitignore

**经验：**
- 提交前检查 `git status`
- 使用 `git diff --cached` 查看暂存内容
- 敏感文件加入 .gitignore

---

### 2. 异步死锁

**问题：** 在同步方法中 `.Result` 或 `.Wait()` 导致死锁

**解决方案：**
- 全链路使用 `async/await`
- 避免 `.Result` 和 `.Wait()`
- 如果必须阻塞，使用 `.GetAwaiter().GetResult()`

**经验：**
- WPF 中特别容易死锁
- ViewModel 的所有方法都应该是 async
- 初始化逻辑放在 `InitializeAsync()`

---

### 3. Process 输出重定向死锁

**问题：** `Process.WaitForExit()` 卡死

**解决方案：**
- 异步读取 StandardOutput 和 StandardError
- 使用 `BeginOutputReadLine()`

**代码示例：**
```csharp
process.OutputDataReceived += (s, e) => { /* 处理输出 */ };
process.ErrorDataReceived += (s, e) => { /* 处理错误 */ };
process.BeginOutputReadLine();
process.BeginErrorReadLine();
await process.WaitForExitAsync();
```

**经验：**
- 必须同时读取 stdout 和 stderr
- 不读取会导致缓冲区满而卡死
- 使用 `WaitForExitAsync()` 而不是 `WaitForExit()`

---

## 性能优化经验

### 1. 网络检测优化

**优化前：** 串行探测 3 个端点，超时 30 秒  
**优化后：** 并行探测，超时 3 秒

**代码：**
```csharp
var tasks = endpoints.Select(url => 
    client.GetAsync(url, HttpCompletionOption.ResponseHeadersRead)
);
var completed = await Task.WhenAny(tasks);
```

**提升：** 启动时间从 30s → 3s

---

### 2. UI 响应优化

**优化前：** 下载时 UI 卡顿  
**优化后：** 使用 `Progress<T>` + 500ms 节流

**代码：**
```csharp
var lastReport = DateTime.MinValue;
if ((DateTime.Now - lastReport).TotalMilliseconds > 500) {
    progress?.Report(new DownloadProgress { ... });
    lastReport = DateTime.Now;
}
```

**提升：** UI 流畅，CPU 占用降低

---

## 文档和规范

### 1. 代码注释规范

**规则：**
- 公共 API 必须有 XML 文档注释
- 复杂逻辑添加行内注释
- 避免无意义注释（如 `// 设置变量`）

**示例：**
```csharp
/// <summary>
/// 下载软件包到指定目录
/// </summary>
/// <param name="package">软件包信息</param>
/// <param name="targetDir">目标目录</param>
/// <param name="progress">进度报告</param>
/// <returns>下载后的文件路径</returns>
public async Task<string> DownloadPackageAsync(
    SoftwarePackage package,
    string targetDir,
    IProgress<DownloadProgress>? progress = null)
```

---

### 2. 提交信息规范

**格式：**
```
<type>(<scope>): <subject>

<body>

<footer>
```

**Type：**
- `feat`: 新功能
- `fix`: Bug 修复
- `docs`: 文档
- `refactor`: 重构

**示例：**
```
feat(download): 添加断点续传支持

实现了 HTTP Range 请求，支持从中断位置继续下载。

Closes #42
```

---

## 工具和资源

### 开发工具
- **IDE:** Visual Studio 2022 / Rider
- **版本控制:** Git + GitHub CLI
- **包管理:** NuGet

### 关键依赖
- `Microsoft.Extensions.DependencyInjection` — DI 容器
- `Microsoft.Extensions.Hosting` — 应用程序生命周期
- `Semver` — 语义化版本解析

### 参考资源
- .NET 文档：https://learn.microsoft.com/dotnet/
- WPF 教程：https://learn.microsoft.com/wpf/
- MVVM 模式：https://learn.microsoft.com/xamarin/xamarin-forms/xaml/xaml-basics/data-binding-basics

---

## 总结

### 成功经验

1. **架构先行** — 先设计 Service 接口，再实现
2. **MVVM 严格分离** — ViewModel 不引用 View
3. **异步全链路** — 避免同步阻塞
4. **安全优先** — 校验 + 检查 + 原子操作
5. **文档齐全** — README + 贡献指南 + 测试指南

### 避免的坑

1. ❌ `git add .` 提交敏感文件
2. ❌ `.Result` / `.Wait()` 导致死锁
3. ❌ Process 输出不读取导致卡死
4. ❌ 下载不校验哈希
5. ❌ 网络检测超时太长

### 项目指标

- **总文件数：** 50
- **代码行数：** ~3520
- **编译时间：** ~3 秒
- **编译状态：** ✅ 0 errors, 0 warnings

---

**项目状态：✅ 完全成功**

所有功能已实现，文档齐全，已开源发布到 GitHub。

**仓库地址：** https://github.com/Hadi777-apk/ZhuangJiAgent

---

**最后更新：** 2026-07-06  
**作者：** 装机Agent 开发团队
