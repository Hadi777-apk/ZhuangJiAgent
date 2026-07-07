using System.IO;
using System.Net.Http;
using System.Text.Json;
using Semver;
using ZhuangJiAgent.Models;

namespace ZhuangJiAgent.Services;

/// <summary>
/// 清单服务实现
/// </summary>
public sealed class ManifestService : IManifestService
{
    private static readonly HttpClient HttpClient = new();
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
        WriteIndented = true
    };

    private const string LocalManifestFileName = "manifest.json";
    private const string DefaultRemoteManifestUrl = "https://raw.githubusercontent.com/Hadi777-apk/ZhuangJiAgent/main/src/ZhuangJiAgent/manifest.json";

    /// <inheritdoc/>
    public async Task<InstallManifest> LoadLocalManifestAsync(CancellationToken cancellationToken = default)
    {
        // 优先使用设置中配置的远程清单 URL（无配置时使用默认仓内清单）
        var localPath = Path.Combine(AppPaths.BaseDirectory, LocalManifestFileName);
        if (!File.Exists(localPath))
        {
            return new InstallManifest
            {
                ManifestVersion = "1.0.0",
                LastUpdated = DateTime.UtcNow,
                AgentVersion = "1.0.0",
                Source = "local"
            };
        }

        var json = await File.ReadAllTextAsync(localPath, cancellationToken);
        var manifest = JsonSerializer.Deserialize<InstallManifest>(json, JsonOptions)
            ?? throw new InvalidOperationException("Failed to deserialize local manifest");

        return manifest with { Source = "local" };
    }

    /// <inheritdoc/>
    public async Task<InstallManifest?> TryFetchRemoteManifestAsync(TimeSpan timeout, CancellationToken cancellationToken = default)
    {
        using var cts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        cts.CancelAfter(timeout);

        try
        {
            var url = ResolveRemoteManifestUrl();
            var json = await HttpClient.GetStringAsync(url, cts.Token);
            var manifest = JsonSerializer.Deserialize<InstallManifest>(json, JsonOptions);

            if (manifest is null)
                return null;

            return manifest with { Source = "remote" };
        }
        catch
        {
            return null;
        }
    }

    /// <summary>
    /// 解析远程清单 URL：设置中显式配置优先，否则使用默认仓内清单。
    /// </summary>
    private static string ResolveRemoteManifestUrl()
    {
        var configured = SettingsService.TryLoadRemoteManifestUrl();
        return !string.IsNullOrWhiteSpace(configured) ? configured! : DefaultRemoteManifestUrl;
    }

    /// <inheritdoc/>
    public async Task<InstallManifest> ResolveEffectiveManifestAsync(CancellationToken cancellationToken = default)
    {
        var localManifest = await LoadLocalManifestAsync(cancellationToken);
        var remoteManifest = await TryFetchRemoteManifestAsync(TimeSpan.FromSeconds(3), cancellationToken);

        return remoteManifest ?? localManifest;
    }

    /// <inheritdoc/>
    public UpdateDiff ComputeDiff(InstallManifest local, InstallManifest remote)
    {
        var localPackages = local.Packages.ToDictionary(p => p.Id);
        var remotePackages = remote.Packages.ToDictionary(p => p.Id);

        var newPackages = new List<SoftwarePackage>();
        var updatedPackages = new List<PackageUpdate>();
        var removedPackages = new List<string>();

        // 查找新增和更新的包
        foreach (var (id, remotePackage) in remotePackages)
        {
            if (!localPackages.TryGetValue(id, out var localPackage))
            {
                // 新增的包
                newPackages.Add(remotePackage);
            }
            else if (IsNewerVersion(remotePackage.Version, localPackage.Version))
            {
                // 版本更新的包
                updatedPackages.Add(new PackageUpdate
                {
                    PackageId = id,
                    CurrentVersion = localPackage.Version,
                    LatestVersion = remotePackage.Version,
                    RemotePackage = remotePackage
                });
            }
        }

        // 查找已移除的包
        foreach (var id in localPackages.Keys)
        {
            if (!remotePackages.ContainsKey(id))
            {
                removedPackages.Add(id);
            }
        }

        // 计算总下载大小
        var totalSize = newPackages.Sum(p => p.Installer.Size)
            + updatedPackages.Sum(u => u.RemotePackage.Installer.Size);

        return new UpdateDiff
        {
            NewPackages = newPackages,
            UpdatedPackages = updatedPackages,
            RemovedPackages = removedPackages,
            TotalDownloadSize = totalSize
        };
    }

    /// <inheritdoc/>
    public async Task SaveLocalManifestAsync(InstallManifest manifest, CancellationToken cancellationToken = default)
    {
        var json = JsonSerializer.Serialize(manifest, JsonOptions);
        var localPath = Path.Combine(AppPaths.BaseDirectory, LocalManifestFileName);

        // 原子写入：先写临时文件，再替换
        var tempPath = localPath + ".tmp";
        await File.WriteAllTextAsync(tempPath, json, cancellationToken);
        File.Move(tempPath, localPath, overwrite: true);
    }

    /// <inheritdoc/>
    public List<string> ValidateManifest(InstallManifest manifest)
    {
        var errors = new List<string>();

        if (string.IsNullOrWhiteSpace(manifest.ManifestVersion))
            errors.Add("ManifestVersion is required");

        if (string.IsNullOrWhiteSpace(manifest.AgentVersion))
            errors.Add("AgentVersion is required");

        if (manifest.Packages.Count == 0)
            errors.Add("Packages list cannot be empty");

        var packageIds = new HashSet<string>();
        foreach (var package in manifest.Packages)
        {
            if (string.IsNullOrWhiteSpace(package.Id))
                errors.Add("Package Id is required");
            else if (!packageIds.Add(package.Id))
                errors.Add($"Duplicate package Id: {package.Id}");

            if (string.IsNullOrWhiteSpace(package.Name))
                errors.Add($"Package {package.Id}: Name is required");

            if (string.IsNullOrWhiteSpace(package.Version))
                errors.Add($"Package {package.Id}: Version is required");

            if (package.Installer.Hash.Length != 64)
                errors.Add($"Package {package.Id}: Hash must be 64 hex characters (SHA256)");
            else if (!IsHashConfigured(package.Installer.Hash))
                errors.Add($"Package {package.Id}: Hash is all zeros or invalid — fill in real SHA256, or omit to skip verification");

            if (package.Installer.Url is null && package.Installer.LocalPath is null)
                errors.Add($"Package {package.Id}: Either Url or LocalPath must be specified");
        }

        return errors;
    }

    private static bool IsNewerVersion(string remoteVersion, string localVersion)
    {
        try
        {
            var remote = SemVersion.Parse(remoteVersion, SemVersionStyles.Any);
            var local = SemVersion.Parse(localVersion, SemVersionStyles.Any);
            return remote.ComparePrecedenceTo(local) > 0;
        }
        catch
        {
            // 如果解析失败，回退到字符串比较
            return string.CompareOrdinal(remoteVersion, localVersion) > 0;
        }
    }

    /// <summary>
    /// 判断哈希是否为已配置的真实哈希（与 DownloadService.IsHashConfigured 同语义）。
    /// 全 0 / 含非十六进制字符视为未配置，校验跳过。
    /// </summary>
    private static bool IsHashConfigured(string hash)
    {
        if (string.IsNullOrWhiteSpace(hash) || hash.Length != 64)
            return false;
        foreach (var c in hash)
        {
            if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')))
                return false;
        }
        return hash.Any(c => c != '0');
    }
}
