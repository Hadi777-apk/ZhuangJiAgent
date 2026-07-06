# GitHub 推送指南

## 步骤 1：在 GitHub 创建仓库

1. 访问 https://github.com/new
2. 填写仓库信息：
   - **Repository name:** `ZhuangJiAgent`
   - **Description:** `Windows 软件批量部署工具 - 在线优先、离线降级`
   - **Visibility:** Public（推荐开源）
   - ⚠️ **不要**勾选 "Add a README file"（我们已有）
   - ⚠️ **不要**添加 .gitignore 或 License（我们已有）

3. 点击 "Create repository"

---

## 步骤 2：推送到 GitHub

创建仓库后，GitHub 会显示推送命令。运行以下命令：

### 方式 1：使用 HTTPS（推荐）

```bash
cd "C:\Users\hardy777\装机agent"

# 添加远程仓库（替换 yourusername）
git remote add origin https://github.com/yourusername/ZhuangJiAgent.git

# 重命名分支为 main（GitHub 默认）
git branch -M main

# 推送到远程仓库
git push -u origin main
```

### 方式 2：使用 SSH

```bash
cd "C:\Users\hardy777\装机agent"

# 添加远程仓库（替换 yourusername）
git remote add origin git@github.com:yourusername/ZhuangJiAgent.git

# 重命名分支为 main
git branch -M main

# 推送到远程仓库
git push -u origin main
```

---

## 步骤 3：验证推送

推送成功后，访问仓库页面：
```
https://github.com/yourusername/ZhuangJiAgent
```

应该能看到：
- ✅ README.md 自动渲染
- ✅ 63 个文件
- ✅ 初始提交
- ✅ MIT License 标签

---

## 步骤 4：配置仓库（可选）

### 添加主题标签（Topics）

在仓库页面点击 "Add topics"，添加：
```
windows, wpf, dotnet, csharp, installer, deployment, package-manager, mvvm
```

### 编辑 About

- **Description:** `Windows 软件批量部署工具 - 在线优先、离线降级架构`
- **Website:** （如有）
- **Topics:** 已添加

### 设置默认分支

如果需要，在 Settings → Branches 设置 `main` 为默认分支。

---

## 步骤 5：创建首个 Release

1. 点击右侧 "Releases" → "Create a new release"
2. 填写信息：
   - **Tag:** `v1.0.0`
   - **Release title:** `v1.0.0 - 初始发布`
   - **Description:**

```markdown
## 🎉 装机 Agent v1.0.0 正式发布！

首个稳定版本，功能完整，可立即使用。

### ✨ 核心特性

- ✅ 在线优先、离线降级架构
- ✅ 清单驱动差异化同步
- ✅ 并行下载 + 断点续传
- ✅ SHA256 双重校验
- ✅ 多安装器支持（Exe/MSI/MSIX/Winget）
- ✅ 智能软件检测（Registry/File/Command）
- ✅ 可视化进度条 + 搜索过滤
- ✅ 完整设置页面

### 📥 下载安装

**系统要求：**
- Windows 10/11 (x64)
- .NET 9 Desktop Runtime

**安装步骤：**
1. 下载 `ZhuangJiAgent-v1.0.0.zip`
2. 解压到任意目录
3. 运行 `ZhuangJiAgent.exe`

### 📚 文档

- [使用指南](https://github.com/yourusername/ZhuangJiAgent#使用指南)
- [贡献指南](https://github.com/yourusername/ZhuangJiAgent/blob/main/CONTRIBUTING.md)

### 🙏 致谢

感谢所有贡献者和测试者！
```

3. 上传编译好的 ZIP 包（如有）
4. 点击 "Publish release"

---

## 故障排查

### 推送被拒绝（Authentication failed）

**HTTPS 方式：**
- 使用 Personal Access Token（不是密码）
- 生成 Token：Settings → Developer settings → Personal access tokens → Tokens (classic)
- 权限：勾选 `repo`

**SSH 方式：**
- 配置 SSH Key：Settings → SSH and GPG keys
- 测试连接：`ssh -T git@github.com`

### 推送超时

```bash
# 增加缓冲区大小
git config --global http.postBuffer 524288000

# 使用浅克隆（如果仓库很大）
git push --set-upstream origin main --depth=1
```

---

## 下一步

推送成功后：

1. ✅ 在 README 中更新仓库链接
2. ✅ 配置 GitHub Actions（已有 CI/CD 配置）
3. ✅ 邀请协作者
4. ✅ 社区推广（Reddit/V2EX/知乎）

---

**准备好后，运行推送命令即可！** 🚀
