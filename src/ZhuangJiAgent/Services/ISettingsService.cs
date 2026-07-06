using ZhuangJiAgent.Models;

namespace ZhuangJiAgent.Services;

/// <summary>
/// 设置服务接口
/// </summary>
public interface ISettingsService
{
    /// <summary>
    /// 加载设置
    /// </summary>
    Task<AppSettings> LoadSettingsAsync(CancellationToken cancellationToken = default);

    /// <summary>
    /// 保存设置
    /// </summary>
    Task SaveSettingsAsync(AppSettings settings, CancellationToken cancellationToken = default);
}
