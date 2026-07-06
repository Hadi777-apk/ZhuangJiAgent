using System.Text.Json.Serialization;

namespace ZhuangJiAgent.Models;

/// <summary>
/// 安装程序信息
/// </summary>
public record InstallerInfo
{
    /// <summary>
    /// 安装程序类型
    /// </summary>
    [JsonPropertyName("type")]
    public InstallerType Type { get; init; } = InstallerType.Exe;

    /// <summary>
    /// 在线下载地址
    /// </summary>
    [JsonPropertyName("url")]
    public string? Url { get; init; }

    /// <summary>
    /// 本地离线分卷路径（相对于程序根目录）
    /// </summary>
    [JsonPropertyName("localPath")]
    public string? LocalPath { get; init; }

    /// <summary>
    /// SHA256 哈希值（十六进制字符串）
    /// </summary>
    [JsonPropertyName("hash")]
    public string Hash { get; init; } = string.Empty;

    /// <summary>
    /// 文件大小（字节）
    /// </summary>
    [JsonPropertyName("size")]
    public long Size { get; init; }

    /// <summary>
    /// 静默安装参数
    /// </summary>
    [JsonPropertyName("silentArgs")]
    public string SilentArgs { get; init; } = string.Empty;

    /// <summary>
    /// WinGet 包 ID（仅 Winget 类型）
    /// </summary>
    [JsonPropertyName("wingetId")]
    public string? WingetId { get; init; }

    /// <summary>
    /// 镜像下载地址列表（备用）
    /// </summary>
    [JsonPropertyName("mirrors")]
    public List<string>? Mirrors { get; init; }

    /// <summary>
    /// 特殊说明（如版本兼容性、UAC 提示等）
    /// </summary>
    [JsonPropertyName("notes")]
    public string? Notes { get; init; }
}
