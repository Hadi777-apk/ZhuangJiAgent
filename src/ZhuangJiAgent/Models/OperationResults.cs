namespace ZhuangJiAgent.Models;

/// <summary>
/// 下载进度信息
/// </summary>
public record DownloadProgress
{
    /// <summary>
    /// 软件包 ID
    /// </summary>
    public string PackageId { get; init; } = string.Empty;

    /// <summary>
    /// 已下载字节数
    /// </summary>
    public long BytesDownloaded { get; init; }

    /// <summary>
    /// 总字节数
    /// </summary>
    public long TotalBytes { get; init; }

    /// <summary>
    /// 下载进度百分比 (0-100)
    /// </summary>
    public double ProgressPercentage => TotalBytes > 0 ? (BytesDownloaded * 100.0 / TotalBytes) : 0;

    /// <summary>
    /// 下载速度（字节/秒）
    /// </summary>
    public long BytesPerSecond { get; init; }

    /// <summary>
    /// 预估剩余时间（秒）
    /// </summary>
    public double EstimatedSecondsRemaining
    {
        get
        {
            if (BytesPerSecond <= 0) return 0;
            var remaining = TotalBytes - BytesDownloaded;
            return remaining / (double)BytesPerSecond;
        }
    }

    /// <summary>
    /// 当前状态
    /// </summary>
    public DownloadState State { get; init; } = DownloadState.Pending;

    /// <summary>
    /// 错误信息（如果失败）
    /// </summary>
    public string? ErrorMessage { get; init; }
}

/// <summary>
/// 下载状态
/// </summary>
public enum DownloadState
{
    Pending,
    Downloading,
    Verifying,
    Completed,
    Failed,
    Cancelled
}

/// <summary>
/// 安装结果
/// </summary>
public record InstallResult
{
    /// <summary>
    /// 是否成功
    /// </summary>
    public bool Success { get; init; }

    /// <summary>
    /// 软件包 ID
    /// </summary>
    public string PackageId { get; init; } = string.Empty;

    /// <summary>
    /// 安装状态
    /// </summary>
    public InstallStatus Status { get; init; }

    /// <summary>
    /// 错误信息
    /// </summary>
    public string? ErrorMessage { get; init; }

    /// <summary>
    /// 安装器退出码
    /// </summary>
    public int? ExitCode { get; init; }

    /// <summary>
    /// 安装耗时（秒）
    /// </summary>
    public double ElapsedSeconds { get; init; }

    /// <summary>
    /// 是否需要重启
    /// </summary>
    public bool RequiresReboot { get; init; }
}
