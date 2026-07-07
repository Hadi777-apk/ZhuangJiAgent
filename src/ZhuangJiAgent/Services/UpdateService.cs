using System.IO;
using ZhuangJiAgent.Models;

namespace ZhuangJiAgent.Services;

/// <summary>
/// 更新服务实现
/// </summary>
public sealed class UpdateService : IUpdateService
{
    private readonly ISourceResolver _sourceResolver;
    private readonly IManifestService _manifestService;
    private readonly IDownloadService _downloadService;

    private const string DownloadCacheDirectory = "downloads/latest";

    public UpdateService(
        ISourceResolver sourceResolver,
        IManifestService manifestService,
        IDownloadService downloadService)
    {
        _sourceResolver = sourceResolver;
        _manifestService = manifestService;
        _downloadService = downloadService;
    }

    /// <inheritdoc/>
    public async Task<UpdateReport> CheckForUpdatesAsync(CancellationToken cancellationToken = default)
    {
        return await _sourceResolver.CheckForUpdatesAsync(cancellationToken);
    }

    /// <inheritdoc/>
    public async Task<bool> ApplyUpdatesAsync(
        UpdateReport report,
        IProgress<DownloadProgress>? progress = null,
        CancellationToken cancellationToken = default)
    {
        if (!report.HasUpdates || report.Diff is null)
            return true;

        try
        {
            // 收集所有需要下载的包
            var packagesToDownload = new List<SoftwarePackage>();
            packagesToDownload.AddRange(report.Diff.NewPackages);
            packagesToDownload.AddRange(report.Diff.UpdatedPackages.Select(u => u.RemotePackage));

            if (packagesToDownload.Count == 0)
                return true;

            // 空间预占用检查（审查建议）
            var totalSize = report.Diff.TotalDownloadSize;
            if (!_downloadService.CheckDiskSpace(DownloadCacheDirectory, totalSize))
            {
                throw new InvalidOperationException(
                    $"磁盘空间不足。需要 {FormatBytes(totalSize)}，请清理磁盘后重试。");
            }

            // 下载所有更新
            var downloadedFiles = await DownloadUpdatesAsync(
                packagesToDownload,
                progress,
                cancellationToken);

            // 验证所有下载完成
            if (downloadedFiles.Count != packagesToDownload.Count)
            {
                throw new InvalidOperationException("部分软件包下载失败");
            }

            // 安装前二次哈希校验（审查建议）
            foreach (var package in packagesToDownload)
            {
                if (!downloadedFiles.TryGetValue(package.Id, out var filePath))
                    continue;

                // 清单配置了真实哈希才校验，否则跳过（与 DownloadService 行为一致）
                if (!DownloadService.IsHashConfigured(package.Installer.Hash))
                    continue;

                var isValid = await _downloadService.VerifyHashAsync(
                    filePath,
                    package.Installer.Hash,
                    cancellationToken);

                if (!isValid)
                {
                    throw new InvalidOperationException(
                        $"软件包 {package.Name} 哈希校验失败，文件可能已损坏");
                }
            }

            // 所有下载和校验成功后，原子更新本地清单
            var localManifest = await _manifestService.LoadLocalManifestAsync(cancellationToken);
            var updatedManifest = MergeManifests(localManifest, report.Diff);

            await _manifestService.SaveLocalManifestAsync(updatedManifest, cancellationToken);

            return true;
        }
        catch
        {
            // 更新失败，不修改本地清单
            throw;
        }
    }

    /// <inheritdoc/>
    public async Task<Dictionary<string, string>> DownloadUpdatesAsync(
        IEnumerable<SoftwarePackage> packages,
        IProgress<DownloadProgress>? progress = null,
        CancellationToken cancellationToken = default)
    {
        Directory.CreateDirectory(DownloadCacheDirectory);

        return await _downloadService.DownloadPackagesAsync(
            packages,
            DownloadCacheDirectory,
            progress,
            cancellationToken);
    }

    private static InstallManifest MergeManifests(InstallManifest local, UpdateDiff diff)
    {
        var packages = local.Packages.ToDictionary(p => p.Id);

        // 添加新包
        foreach (var newPackage in diff.NewPackages)
        {
            packages[newPackage.Id] = newPackage;
        }

        // 更新现有包
        foreach (var update in diff.UpdatedPackages)
        {
            packages[update.PackageId] = update.RemotePackage;
        }

        // 移除已删除的包
        foreach (var removedId in diff.RemovedPackages)
        {
            packages.Remove(removedId);
        }

        return local with
        {
            Packages = packages.Values.OrderBy(p => p.Order).ToList(),
            LastUpdated = DateTime.UtcNow
        };
    }

    private static string FormatBytes(long bytes)
    {
        string[] sizes = ["B", "KB", "MB", "GB"];
        double len = bytes;
        int order = 0;

        while (len >= 1024 && order < sizes.Length - 1)
        {
            order++;
            len /= 1024;
        }

        return $"{len:0.##} {sizes[order]}";
    }
}
