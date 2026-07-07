using System.IO;
using System.Text.Json;
using ZhuangJiAgent.Models;

namespace ZhuangJiAgent.Services;

/// <summary>
/// 设置服务实现
/// </summary>
public sealed class SettingsService : ISettingsService
{
    private const string SettingsFileName = "appsettings.json";

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
        WriteIndented = true
    };

    private static string SettingsFilePath => Path.Combine(AppPaths.BaseDirectory, SettingsFileName);

    /// <inheritdoc/>
    public async Task<AppSettings> LoadSettingsAsync(CancellationToken cancellationToken = default)
    {
        if (!File.Exists(SettingsFilePath))
        {
            return new AppSettings();
        }

        try
        {
            var json = await File.ReadAllTextAsync(SettingsFilePath, cancellationToken);
            return JsonSerializer.Deserialize<AppSettings>(json, JsonOptions) ?? new AppSettings();
        }
        catch
        {
            return new AppSettings();
        }
    }

    /// <inheritdoc/>
    public async Task SaveSettingsAsync(AppSettings settings, CancellationToken cancellationToken = default)
    {
        var json = JsonSerializer.Serialize(settings, JsonOptions);

        // 原子写入
        var tempPath = SettingsFilePath + ".tmp";
        await File.WriteAllTextAsync(tempPath, json, cancellationToken);
        File.Move(tempPath, SettingsFilePath, overwrite: true);
    }

    /// <summary>
    /// 同步读取已配置的远程清单 URL（供 ManifestService 在启动期使用，避免循环依赖）。
    /// 配置缺失或读取失败时返回 null。
    /// </summary>
    internal static string? TryLoadRemoteManifestUrl()
    {
        try
        {
            if (!File.Exists(SettingsFilePath))
                return null;
            var json = File.ReadAllText(SettingsFilePath);
            return JsonSerializer.Deserialize<AppSettings>(json, JsonOptions)?.RemoteManifestUrl;
        }
        catch
        {
            return null;
        }
    }
}
