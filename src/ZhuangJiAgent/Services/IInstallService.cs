using ZhuangJiAgent.Models;

namespace ZhuangJiAgent.Services;

/// <summary>
/// 安装服务接口
/// </summary>
public interface IInstallService
{
    /// <summary>
    /// 安装单个软件包
    /// </summary>
    /// <param name="package">软件包信息</param>
    /// <param name="installerPath">安装程序路径</param>
    /// <param name="cancellationToken">取消令牌</param>
    /// <returns>安装结果</returns>
    Task<InstallResult> InstallPackageAsync(
        SoftwarePackage package,
        string installerPath,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// 批量安装软件包
    /// </summary>
    /// <param name="packages">软件包列表（需包含本地文件路径）</param>
    /// <param name="installerPaths">安装程序路径字典（包ID -> 文件路径）</param>
    /// <param name="cancellationToken">取消令牌</param>
    /// <returns>安装结果列表</returns>
    Task<List<InstallResult>> InstallPackagesAsync(
        IEnumerable<SoftwarePackage> packages,
        Dictionary<string, string> installerPaths,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// 检查并安装（已安装则跳过）
    /// </summary>
    /// <param name="package">软件包信息</param>
    /// <param name="installerPath">安装程序路径</param>
    /// <param name="cancellationToken">取消令牌</param>
    /// <returns>安装结果</returns>
    Task<InstallResult> CheckAndInstallAsync(
        SoftwarePackage package,
        string installerPath,
        CancellationToken cancellationToken = default);
}
