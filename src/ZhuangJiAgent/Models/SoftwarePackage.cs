using System.Text.Json.Serialization;

namespace ZhuangJiAgent.Models;

/// <summary>
/// 软件包定义
/// </summary>
public record SoftwarePackage
{
    /// <summary>
    /// 唯一标识符（用于差异对比）
    /// </summary>
    [JsonPropertyName("id")]
    public string Id { get; init; } = string.Empty;

    /// <summary>
    /// 显示名称
    /// </summary>
    [JsonPropertyName("name")]
    public string Name { get; init; } = string.Empty;

    /// <summary>
    /// 版本号（语义化版本）
    /// </summary>
    [JsonPropertyName("version")]
    public string Version { get; init; } = string.Empty;

    /// <summary>
    /// 分类（如 Runtime, Browser, Utility, DevTools）
    /// </summary>
    [JsonPropertyName("category")]
    public string Category { get; init; } = string.Empty;

    /// <summary>
    /// 发布者
    /// </summary>
    [JsonPropertyName("publisher")]
    public string Publisher { get; init; } = string.Empty;

    /// <summary>
    /// 简短描述
    /// </summary>
    [JsonPropertyName("description")]
    public string? Description { get; init; }

    /// <summary>
    /// 安装程序信息
    /// </summary>
    [JsonPropertyName("installer")]
    public InstallerInfo Installer { get; init; } = new();

    /// <summary>
    /// 检测信息（如何判断软件是否已安装）
    /// </summary>
    [JsonPropertyName("detection")]
    public DetectionInfo? Detection { get; init; }

    /// <summary>
    /// 依赖的其他包 ID 列表
    /// </summary>
    [JsonPropertyName("dependencies")]
    public List<string>? Dependencies { get; init; }

    /// <summary>
    /// 安装顺序（数字越小越优先）
    /// </summary>
    [JsonPropertyName("order")]
    public int Order { get; init; }

    /// <summary>
    /// 是否默认选中
    /// </summary>
    [JsonPropertyName("defaultSelected")]
    public bool DefaultSelected { get; init; } = true;

    /// <summary>
    /// 标签（用于过滤和搜索）
    /// </summary>
    [JsonPropertyName("tags")]
    public List<string>? Tags { get; init; }
}
