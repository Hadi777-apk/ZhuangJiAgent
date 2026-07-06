using ZhuangJiAgent.Models;

namespace ZhuangJiAgent.Services;

/// <summary>
/// 软件检测服务接口
/// </summary>
public interface IDetectionService
{
    /// <summary>
    /// 检测软件是否已安装
    /// </summary>
    /// <param name="package">软件包信息</param>
    /// <param name="cancellationToken">取消令牌</param>
    /// <returns>检测结果（是否已安装）</returns>
    Task<bool> IsInstalledAsync(SoftwarePackage package, CancellationToken cancellationToken = default);

    /// <summary>
    /// 获取已安装软件的版本
    /// </summary>
    /// <param name="package">软件包信息</param>
    /// <param name="cancellationToken">取消令牌</param>
    /// <returns>已安装的版本（未安装返回 null）</returns>
    Task<string?> GetInstalledVersionAsync(SoftwarePackage package, CancellationToken cancellationToken = default);

    /// <summary>
    /// 检测软件版本是否匹配预期
    /// </summary>
    /// <param name="package">软件包信息</param>
    /// <param name="cancellationToken">取消令牌</param>
    /// <returns>是否匹配</returns>
    Task<bool> IsVersionMatchAsync(SoftwarePackage package, CancellationToken cancellationToken = default);
}
