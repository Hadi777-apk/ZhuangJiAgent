using System.Text.Json.Serialization;

namespace ZhuangJiAgent.Models;

/// <summary>
/// Agent 自身更新信息
/// </summary>
public record AgentUpdateInfo
{
    /// <summary>
    /// 最新版本号
    /// </summary>
    [JsonPropertyName("latestVersion")]
    public string LatestVersion { get; init; } = string.Empty;

    /// <summary>
    /// 下载地址
    /// </summary>
    [JsonPropertyName("downloadUrl")]
    public string DownloadUrl { get; init; } = string.Empty;

    /// <summary>
    /// 更新说明（Markdown 格式）
    /// </summary>
    [JsonPropertyName("releaseNotes")]
    public string? ReleaseNotes { get; init; }

    /// <summary>
    /// 发布日期
    /// </summary>
    [JsonPropertyName("releaseDate")]
    public DateTime ReleaseDate { get; init; }

    /// <summary>
    /// 是否强制更新
    /// </summary>
    [JsonPropertyName("mandatory")]
    public bool Mandatory { get; init; }
}

/// <summary>
/// 软件安装清单（完整清单文件的根对象）
/// </summary>
public record InstallManifest
{
    /// <summary>
    /// 清单格式版本
    /// </summary>
    [JsonPropertyName("manifestVersion")]
    public string ManifestVersion { get; init; } = "1.0.0";

    /// <summary>
    /// 清单最后更新时间
    /// </summary>
    [JsonPropertyName("lastUpdated")]
    public DateTime LastUpdated { get; init; }

    /// <summary>
    /// Agent 版本（清单对应的工具版本）
    /// </summary>
    [JsonPropertyName("agentVersion")]
    public string AgentVersion { get; init; } = string.Empty;

    /// <summary>
    /// Agent 自身更新信息（可选）
    /// </summary>
    [JsonPropertyName("updateInfo")]
    public AgentUpdateInfo? UpdateInfo { get; init; }

    /// <summary>
    /// 软件包列表
    /// </summary>
    [JsonPropertyName("packages")]
    public List<SoftwarePackage> Packages { get; init; } = [];

    /// <summary>
    /// 清单来源（用于标识是本地还是远程）
    /// </summary>
    [JsonIgnore]
    public string Source { get; init; } = "local";
}
