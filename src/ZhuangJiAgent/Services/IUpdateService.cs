using ZhuangJiAgent.Models;

namespace ZhuangJiAgent.Services;

/// <summary>
/// 更新服务接口
/// </summary>
public interface IUpdateService
{
    /// <summary>
    /// 检查是否有可用更新
    /// </summary>
    /// <param name="cancellationToken">取消令牌</param>
    /// <returns>更新报告</returns>
    Task<UpdateReport> CheckForUpdatesAsync(CancellationToken cancellationToken = default);

    /// <summary>
    /// 应用更新（下载并更新本地清单）
    /// </summary>
    /// <param name="report">更新报告</param>
    /// <param name="progress">进度回调</param>
    /// <param name="cancellationToken">取消令牌</param>
    /// <returns>是否成功</returns>
    Task<bool> ApplyUpdatesAsync(
        UpdateReport report,
        IProgress<DownloadProgress>? progress = null,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// 下载特定软件包到缓存目录
    /// </summary>
    /// <param name="packages">软件包列表</param>
    /// <param name="progress">进度回调</param>
    /// <param name="cancellationToken">取消令牌</param>
    /// <returns>下载结果（包ID -> 文件路径）</returns>
    Task<Dictionary<string, string>> DownloadUpdatesAsync(
        IEnumerable<SoftwarePackage> packages,
        IProgress<DownloadProgress>? progress = null,
        CancellationToken cancellationToken = default);
}
