using ZhuangJiAgent.Models;

namespace ZhuangJiAgent.Services;

/// <summary>
/// 下载服务接口
/// </summary>
public interface IDownloadService
{
    /// <summary>
    /// 下载单个软件包
    /// </summary>
    /// <param name="package">软件包信息</param>
    /// <param name="targetDirectory">目标目录</param>
    /// <param name="progress">进度回调</param>
    /// <param name="cancellationToken">取消令牌</param>
    /// <returns>下载的文件路径</returns>
    Task<string> DownloadPackageAsync(
        SoftwarePackage package,
        string targetDirectory,
        IProgress<DownloadProgress>? progress = null,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// 并行下载多个软件包
    /// </summary>
    /// <param name="packages">软件包列表</param>
    /// <param name="targetDirectory">目标目录</param>
    /// <param name="progress">进度回调</param>
    /// <param name="cancellationToken">取消令牌</param>
    /// <returns>下载结果（包ID -> 文件路径）</returns>
    Task<Dictionary<string, string>> DownloadPackagesAsync(
        IEnumerable<SoftwarePackage> packages,
        string targetDirectory,
        IProgress<DownloadProgress>? progress = null,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// 验证文件哈希
    /// </summary>
    /// <param name="filePath">文件路径</param>
    /// <param name="expectedHash">期望的SHA256哈希（十六进制）</param>
    /// <param name="cancellationToken">取消令牌</param>
    /// <returns>是否匹配</returns>
    Task<bool> VerifyHashAsync(
        string filePath,
        string expectedHash,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// 检查磁盘空间是否足够
    /// </summary>
    /// <param name="targetDirectory">目标目录</param>
    /// <param name="requiredBytes">需要的字节数</param>
    /// <returns>是否有足够空间</returns>
    bool CheckDiskSpace(string targetDirectory, long requiredBytes);
}
