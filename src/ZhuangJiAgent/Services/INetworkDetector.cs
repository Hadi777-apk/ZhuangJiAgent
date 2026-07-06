using ZhuangJiAgent.Models;

namespace ZhuangJiAgent.Services;

/// <summary>
/// 网络连通性检测服务
/// </summary>
public interface INetworkDetector
{
    /// <summary>
    /// 异步检测网络连接状态
    /// </summary>
    /// <param name="cancellationToken">取消令牌</param>
    /// <returns>网络状态</returns>
    Task<NetworkState> DetectAsync(CancellationToken cancellationToken = default);

    /// <summary>
    /// 检测是否在线（快速判断）
    /// </summary>
    /// <param name="cancellationToken">取消令牌</param>
    /// <returns>是否在线</returns>
    Task<bool> IsOnlineAsync(CancellationToken cancellationToken = default);
}
