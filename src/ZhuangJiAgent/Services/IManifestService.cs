using ZhuangJiAgent.Models;

namespace ZhuangJiAgent.Services;

/// <summary>
/// 清单服务接口
/// </summary>
public interface IManifestService
{
    /// <summary>
    /// 从本地文件加载清单（离线快照）
    /// </summary>
    /// <param name="cancellationToken">取消令牌</param>
    /// <returns>本地清单</returns>
    Task<InstallManifest> LoadLocalManifestAsync(CancellationToken cancellationToken = default);

    /// <summary>
    /// 尝试从远程服务器获取清单
    /// </summary>
    /// <param name="timeout">超时时间</param>
    /// <param name="cancellationToken">取消令牌</param>
    /// <returns>远程清单（失败时返回 null）</returns>
    Task<InstallManifest?> TryFetchRemoteManifestAsync(TimeSpan timeout, CancellationToken cancellationToken = default);

    /// <summary>
    /// 解析生效的清单（在线优先，离线降级）
    /// </summary>
    /// <param name="cancellationToken">取消令牌</param>
    /// <returns>当前生效的清单</returns>
    Task<InstallManifest> ResolveEffectiveManifestAsync(CancellationToken cancellationToken = default);

    /// <summary>
    /// 计算两个清单之间的差异
    /// </summary>
    /// <param name="local">本地清单</param>
    /// <param name="remote">远程清单</param>
    /// <returns>差异对比结果</returns>
    UpdateDiff ComputeDiff(InstallManifest local, InstallManifest remote);

    /// <summary>
    /// 保存清单到本地
    /// </summary>
    /// <param name="manifest">要保存的清单</param>
    /// <param name="cancellationToken">取消令牌</param>
    Task SaveLocalManifestAsync(InstallManifest manifest, CancellationToken cancellationToken = default);

    /// <summary>
    /// 验证清单格式有效性
    /// </summary>
    /// <param name="manifest">要验证的清单</param>
    /// <returns>验证结果（空列表表示有效）</returns>
    List<string> ValidateManifest(InstallManifest manifest);
}
