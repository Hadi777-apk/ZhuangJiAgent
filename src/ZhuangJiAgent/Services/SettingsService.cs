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

    /// <inheritdoc/>
    public async Task<AppSettings> LoadSettingsAsync(CancellationToken cancellationToken = default)
    {
        if (!File.Exists(SettingsFileName))
        {
            return new AppSettings();
        }

        try
        {
            var json = await File.ReadAllTextAsync(SettingsFileName, cancellationToken);
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
        var tempPath = SettingsFileName + ".tmp";
        await File.WriteAllTextAsync(tempPath, json, cancellationToken);
        File.Move(tempPath, SettingsFileName, overwrite: true);
    }
}
