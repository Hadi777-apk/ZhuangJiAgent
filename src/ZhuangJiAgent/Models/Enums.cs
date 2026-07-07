namespace ZhuangJiAgent.Models;

/// <summary>
/// 安装程序类型
/// </summary>
public enum InstallerType
{
    /// <summary>
    /// 可执行文件 (.exe)
    /// </summary>
    Exe,

    /// <summary>
    /// MSI 安装包
    /// </summary>
    Msi,

    /// <summary>
    /// MSIX/APPX 包
    /// </summary>
    Msix,

    /// <summary>
    /// 使用 WinGet 包管理器
    /// </summary>
    Winget,

    /// <summary>
    /// 压缩包（需手动解压）
    /// </summary>
    Archive
}

/// <summary>
/// 软件检测类型
/// </summary>
public enum DetectionType
{
    /// <summary>
    /// 通过注册表检测
    /// </summary>
    Registry,

    /// <summary>
    /// 通过文件存在性检测
    /// </summary>
    File,

    /// <summary>
    /// 通过命令行输出检测
    /// </summary>
    Command,

    /// <summary>
    /// 不检测，始终安装
    /// </summary>
    None
}

/// <summary>
/// 网络连接状态
/// </summary>
public enum NetworkState
{
    /// <summary>
    /// 在线（可访问互联网）
    /// </summary>
    Online,

    /// <summary>
    /// 离线
    /// </summary>
    Offline,

    /// <summary>
    /// 未知（检测超时或异常）
    /// </summary>
    Unknown
}

/// <summary>
/// 安装结果状态
/// </summary>
public enum InstallStatus
{
    /// <summary>
    /// 成功
    /// </summary>
    Success,

    /// <summary>
    /// 已安装（跳过）
    /// </summary>
    AlreadyInstalled,

    /// <summary>
    /// 失败
    /// </summary>
    Failed,

    /// <summary>
    /// 已取消
    /// </summary>
    Cancelled,

    /// <summary>
    /// 等待中
    /// </summary>
    Pending,

    /// <summary>
    /// 正在安装
    /// </summary>
    Installing
}
