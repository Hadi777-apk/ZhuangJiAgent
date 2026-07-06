using System.Text.Json.Serialization;

namespace ZhuangJiAgent.Models;

/// <summary>
/// 软件检测信息
/// </summary>
public record DetectionInfo
{
    /// <summary>
    /// 检测类型
    /// </summary>
    [JsonPropertyName("type")]
    public DetectionType Type { get; init; } = DetectionType.None;

    /// <summary>
    /// 注册表键路径（仅 Registry 类型）
    /// </summary>
    [JsonPropertyName("registryKey")]
    public string? RegistryKey { get; init; }

    /// <summary>
    /// 注册表值名称（仅 Registry 类型）
    /// </summary>
    [JsonPropertyName("registryValue")]
    public string? RegistryValue { get; init; }

    /// <summary>
    /// 文件路径（仅 File 类型）
    /// </summary>
    [JsonPropertyName("filePath")]
    public string? FilePath { get; init; }

    /// <summary>
    /// 检测命令（仅 Command 类型）
    /// </summary>
    [JsonPropertyName("command")]
    public string? Command { get; init; }

    /// <summary>
    /// 期望的版本号
    /// </summary>
    [JsonPropertyName("expectedVersion")]
    public string? ExpectedVersion { get; init; }
}
