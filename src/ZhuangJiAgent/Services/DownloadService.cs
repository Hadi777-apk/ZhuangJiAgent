using System.IO;
using System.Net.Http;
using System.Security.Cryptography;
using ZhuangJiAgent.Models;

namespace ZhuangJiAgent.Services;

/// <summary>
/// 下载服务实现
/// </summary>
public sealed class DownloadService : IDownloadService
{
    private static readonly HttpClient HttpClient = new()
    {
        Timeout = TimeSpan.FromMinutes(10)
    };

    private const int MaxConcurrentDownloads = 3;
    private const int BufferSize = 8192;

    /// <inheritdoc/>
    public async Task<string> DownloadPackageAsync(
        SoftwarePackage package,
        string targetDirectory,
        IProgress<DownloadProgress>? progress = null,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(package.Installer.Url))
            throw new InvalidOperationException($"Package {package.Id} has no download URL");

        Directory.CreateDirectory(targetDirectory);

        var fileName = Path.GetFileName(new Uri(package.Installer.Url).LocalPath);
        var targetPath = Path.Combine(targetDirectory, fileName);

        // 报告开始
        progress?.Report(new DownloadProgress
        {
            PackageId = package.Id,
            BytesDownloaded = 0,
            TotalBytes = package.Installer.Size,
            State = DownloadState.Downloading
        });

        try
        {
            // 下载文件（支持断点续传）
            await DownloadFileWithResumeAsync(
                package.Installer.Url,
                targetPath,
                package.Installer.Size,
                package.Id,
                progress,
                cancellationToken);

            // 报告验证中
            progress?.Report(new DownloadProgress
            {
                PackageId = package.Id,
                BytesDownloaded = package.Installer.Size,
                TotalBytes = package.Installer.Size,
                State = DownloadState.Verifying
            });

            // 验证哈希
            var isValid = await VerifyHashAsync(targetPath, package.Installer.Hash, cancellationToken);

            if (!isValid)
            {
                File.Delete(targetPath);
                throw new InvalidOperationException($"Hash verification failed for package {package.Id}");
            }

            // 报告完成
            progress?.Report(new DownloadProgress
            {
                PackageId = package.Id,
                BytesDownloaded = package.Installer.Size,
                TotalBytes = package.Installer.Size,
                State = DownloadState.Completed
            });

            return targetPath;
        }
        catch (Exception ex)
        {
            progress?.Report(new DownloadProgress
            {
                PackageId = package.Id,
                State = DownloadState.Failed,
                ErrorMessage = ex.Message
            });
            throw;
        }
    }

    /// <inheritdoc/>
    public async Task<Dictionary<string, string>> DownloadPackagesAsync(
        IEnumerable<SoftwarePackage> packages,
        string targetDirectory,
        IProgress<DownloadProgress>? progress = null,
        CancellationToken cancellationToken = default)
    {
        var packageList = packages.ToList();
        var results = new Dictionary<string, string>();
        var semaphore = new SemaphoreSlim(MaxConcurrentDownloads);

        var downloadTasks = packageList.Select(async package =>
        {
            await semaphore.WaitAsync(cancellationToken);
            try
            {
                var filePath = await DownloadPackageAsync(
                    package,
                    targetDirectory,
                    progress,
                    cancellationToken);

                lock (results)
                {
                    results[package.Id] = filePath;
                }
            }
            finally
            {
                semaphore.Release();
            }
        });

        await Task.WhenAll(downloadTasks);
        return results;
    }

    /// <inheritdoc/>
    public async Task<bool> VerifyHashAsync(
        string filePath,
        string expectedHash,
        CancellationToken cancellationToken = default)
    {
        if (!File.Exists(filePath))
            return false;

        using var stream = File.OpenRead(filePath);
        using var sha256 = SHA256.Create();

        var hashBytes = await sha256.ComputeHashAsync(stream, cancellationToken);
        var actualHash = Convert.ToHexString(hashBytes).ToLowerInvariant();

        return actualHash.Equals(expectedHash.ToLowerInvariant(), StringComparison.Ordinal);
    }

    /// <inheritdoc/>
    public bool CheckDiskSpace(string targetDirectory, long requiredBytes)
    {
        try
        {
            var drive = new DriveInfo(Path.GetPathRoot(Path.GetFullPath(targetDirectory))!);
            return drive.AvailableFreeSpace >= requiredBytes;
        }
        catch
        {
            return false;
        }
    }

    private static async Task DownloadFileWithResumeAsync(
        string url,
        string targetPath,
        long expectedSize,
        string packageId,
        IProgress<DownloadProgress>? progress,
        CancellationToken cancellationToken)
    {
        long startPosition = 0;

        // 检查是否存在部分下载的文件
        if (File.Exists(targetPath))
        {
            var fileInfo = new FileInfo(targetPath);
            if (fileInfo.Length < expectedSize)
            {
                startPosition = fileInfo.Length;
            }
            else if (fileInfo.Length == expectedSize)
            {
                // 文件已存在且大小匹配，跳过下载
                return;
            }
            else
            {
                // 文件大小不匹配，删除重新下载
                File.Delete(targetPath);
                startPosition = 0;
            }
        }

        using var request = new HttpRequestMessage(HttpMethod.Get, url);

        // 支持断点续传
        if (startPosition > 0)
        {
            request.Headers.Range = new System.Net.Http.Headers.RangeHeaderValue(startPosition, null);
        }

        using var response = await HttpClient.SendAsync(
            request,
            HttpCompletionOption.ResponseHeadersRead,
            cancellationToken);

        response.EnsureSuccessStatusCode();

        var totalBytes = expectedSize;
        var downloadedBytes = startPosition;

        var fileMode = startPosition > 0 ? FileMode.Append : FileMode.Create;

        await using var contentStream = await response.Content.ReadAsStreamAsync(cancellationToken);
        await using var fileStream = new FileStream(targetPath, fileMode, FileAccess.Write, FileShare.None, BufferSize, useAsync: true);

        var buffer = new byte[BufferSize];
        var lastReportTime = DateTime.UtcNow;
        var lastReportedBytes = downloadedBytes;

        while (true)
        {
            var bytesRead = await contentStream.ReadAsync(buffer, cancellationToken);
            if (bytesRead == 0)
                break;

            await fileStream.WriteAsync(buffer.AsMemory(0, bytesRead), cancellationToken);
            downloadedBytes += bytesRead;

            // 每 500ms 报告一次进度
            var now = DateTime.UtcNow;
            if ((now - lastReportTime).TotalMilliseconds >= 500)
            {
                var elapsed = (now - lastReportTime).TotalSeconds;
                var bytesPerSecond = elapsed > 0 ? (long)((downloadedBytes - lastReportedBytes) / elapsed) : 0;

                progress?.Report(new DownloadProgress
                {
                    PackageId = packageId,
                    BytesDownloaded = downloadedBytes,
                    TotalBytes = totalBytes,
                    BytesPerSecond = bytesPerSecond,
                    State = DownloadState.Downloading
                });

                lastReportTime = now;
                lastReportedBytes = downloadedBytes;
            }
        }
    }
}
