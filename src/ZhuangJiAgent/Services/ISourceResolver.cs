using ZhuangJiAgent.Models;

namespace ZhuangJiAgent.Services;

/// <summary>
/// 数据源解析服务接口（在线优先、离线降级路由）
/// </summary>
public interface ISourceResolver
{
    /// <summary>
    /// 解析当前应使用的清单数据源
    /// </summary>
    /// <param name="cancellationToken">取消令牌</param>
    /// <returns>清单和网络状态</returns>
    Task<(InstallManifest Manifest, NetworkState NetworkState)> ResolveManifestAsync(CancellationToken cancellationToken = default);

    /// <summary>
    /// 检查是否有可用更新
    /// </summary>
    /// <param name="cancellationToken">取消令牌</param>
    /// <returns>更新报告</returns>
    Task<UpdateReport> CheckForUpdatesAsync(CancellationToken cancellationToken = default);
}
