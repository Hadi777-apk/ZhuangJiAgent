using Semver;
using ZhuangJiAgent.Models;

namespace ZhuangJiAgent.Services;

/// <summary>
/// 数据源解析服务实现
/// </summary>
public sealed class SourceResolver : ISourceResolver
{
    private readonly INetworkDetector _networkDetector;
    private readonly IManifestService _manifestService;

    public SourceResolver(INetworkDetector networkDetector, IManifestService manifestService)
    {
        _networkDetector = networkDetector;
        _manifestService = manifestService;
    }

    /// <inheritdoc/>
    public async Task<(InstallManifest Manifest, NetworkState NetworkState)> ResolveManifestAsync(
        CancellationToken cancellationToken = default)
    {
        // 检测网络状态
        var networkState = await _networkDetector.DetectAsync(cancellationToken);

        InstallManifest manifest;

        if (networkState == NetworkState.Online)
        {
            // 在线：尝试获取远程清单
            var remoteManifest = await _manifestService.TryFetchRemoteManifestAsync(
                TimeSpan.FromSeconds(3),
                cancellationToken);

            manifest = remoteManifest ?? await _manifestService.LoadLocalManifestAsync(cancellationToken);
        }
        else
        {
            // 离线：直接使用本地清单
            manifest = await _manifestService.LoadLocalManifestAsync(cancellationToken);
        }

        return (manifest, networkState);
    }

    /// <inheritdoc/>
    public async Task<UpdateReport> CheckForUpdatesAsync(CancellationToken cancellationToken = default)
    {
        var localManifest = await _manifestService.LoadLocalManifestAsync(cancellationToken);

        // 检测网络状态
        var networkState = await _networkDetector.DetectAsync(cancellationToken);

        if (networkState != NetworkState.Online)
        {
            // 离线时返回无更新
            return new UpdateReport
            {
                CheckedAt = DateTime.UtcNow,
                HasUpdates = false,
                LocalManifestVersion = localManifest.ManifestVersion,
                RemoteManifestVersion = string.Empty,
                AgentHasUpdate = false
            };
        }

        // 尝试获取远程清单
        var remoteManifest = await _manifestService.TryFetchRemoteManifestAsync(
            TimeSpan.FromSeconds(5),
            cancellationToken);

        if (remoteManifest is null)
        {
            // 网络可用但获取失败
            return new UpdateReport
            {
                CheckedAt = DateTime.UtcNow,
                HasUpdates = false,
                LocalManifestVersion = localManifest.ManifestVersion,
                RemoteManifestVersion = string.Empty,
                AgentHasUpdate = false
            };
        }

        // 计算差异
        var diff = _manifestService.ComputeDiff(localManifest, remoteManifest);

        // 检查 Agent 自身是否有更新
        var agentHasUpdate = CheckAgentUpdate(localManifest.AgentVersion, remoteManifest.UpdateInfo);

        return new UpdateReport
        {
            CheckedAt = DateTime.UtcNow,
            HasUpdates = diff.HasChanges,
            Diff = diff,
            LocalManifestVersion = localManifest.ManifestVersion,
            RemoteManifestVersion = remoteManifest.ManifestVersion,
            AgentHasUpdate = agentHasUpdate,
            AgentUpdate = remoteManifest.UpdateInfo
        };
    }

    private static bool CheckAgentUpdate(string currentVersion, AgentUpdateInfo? updateInfo)
    {
        if (updateInfo is null)
            return false;

        try
        {
            var current = SemVersion.Parse(currentVersion, SemVersionStyles.Any);
            var latest = SemVersion.Parse(updateInfo.LatestVersion, SemVersionStyles.Any);
            return latest.ComparePrecedenceTo(current) > 0;
        }
        catch
        {
            return false;
        }
    }
}
