namespace ZhuangJiAgent.Models;

/// <summary>
/// 应用程序设置
/// </summary>
public sealed record AppSettings
{
    /// <summary>
    /// 强制离线模式
    /// </summary>
    public bool ForceOfflineMode { get; init; }

    /// <summary>
    /// 下载目录
    /// </summary>
    public string DownloadDirectory { get; init; } = "downloads/cache";

    /// <summary>
    /// 并发下载数（1-5）
    /// </summary>
    public int MaxConcurrentDownloads { get; init; } = 3;

    /// <summary>
    /// 启动时自动检查更新
    /// </summary>
    public bool AutoCheckUpdates { get; init; } = true;

    /// <summary>
    /// 远程清单 URL
    /// </summary>
    public string? RemoteManifestUrl { get; init; }
}
