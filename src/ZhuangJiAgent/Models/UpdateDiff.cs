namespace ZhuangJiAgent.Models;

/// <summary>
/// 清单差异对比结果
/// </summary>
public record UpdateDiff
{
    /// <summary>
    /// 新增的软件包
    /// </summary>
    public List<SoftwarePackage> NewPackages { get; init; } = [];

    /// <summary>
    /// 有版本更新的软件包（远程版本更高）
    /// </summary>
    public List<PackageUpdate> UpdatedPackages { get; init; } = [];

    /// <summary>
    /// 已移除的软件包 ID（本地有但远程已删除）
    /// </summary>
    public List<string> RemovedPackages { get; init; } = [];

    /// <summary>
    /// 是否有任何差异
    /// </summary>
    public bool HasChanges => NewPackages.Count > 0 || UpdatedPackages.Count > 0 || RemovedPackages.Count > 0;

    /// <summary>
    /// 需要下载的总大小（字节）
    /// </summary>
    public long TotalDownloadSize { get; init; }
}

/// <summary>
/// 单个软件包的更新信息
/// </summary>
public record PackageUpdate
{
    /// <summary>
    /// 软件包 ID
    /// </summary>
    public string PackageId { get; init; } = string.Empty;

    /// <summary>
    /// 当前本地版本
    /// </summary>
    public string CurrentVersion { get; init; } = string.Empty;

    /// <summary>
    /// 远程最新版本
    /// </summary>
    public string LatestVersion { get; init; } = string.Empty;

    /// <summary>
    /// 远程软件包完整信息
    /// </summary>
    public SoftwarePackage RemotePackage { get; init; } = new();
}

/// <summary>
/// 更新检查报告
/// </summary>
public record UpdateReport
{
    /// <summary>
    /// 检查时间
    /// </summary>
    public DateTime CheckedAt { get; init; } = DateTime.UtcNow;

    /// <summary>
    /// 是否有可用更新
    /// </summary>
    public bool HasUpdates { get; init; }

    /// <summary>
    /// 差异详情
    /// </summary>
    public UpdateDiff? Diff { get; init; }

    /// <summary>
    /// 本地清单版本
    /// </summary>
    public string LocalManifestVersion { get; init; } = string.Empty;

    /// <summary>
    /// 远程清单版本
    /// </summary>
    public string RemoteManifestVersion { get; init; } = string.Empty;

    /// <summary>
    /// Agent 是否有新版本
    /// </summary>
    public bool AgentHasUpdate { get; init; }

    /// <summary>
    /// Agent 更新信息
    /// </summary>
    public AgentUpdateInfo? AgentUpdate { get; init; }
}
