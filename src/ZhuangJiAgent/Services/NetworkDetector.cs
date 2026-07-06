using System.Net.Http;
using ZhuangJiAgent.Models;

namespace ZhuangJiAgent.Services;

/// <summary>
/// 网络连通性检测服务实现
/// </summary>
public sealed class NetworkDetector : INetworkDetector
{
    private static readonly HttpClient HttpClient = new()
    {
        Timeout = TimeSpan.FromSeconds(3)
    };

    private static readonly string[] ProbeUrls =
    [
        "http://www.msftconnecttest.com/connecttest.txt",
        "https://1.1.1.1",
        "https://www.baidu.com"
    ];

    /// <inheritdoc/>
    public async Task<NetworkState> DetectAsync(CancellationToken cancellationToken = default)
    {
        try
        {
            var isOnline = await IsOnlineAsync(cancellationToken);
            return isOnline ? NetworkState.Online : NetworkState.Offline;
        }
        catch (OperationCanceledException)
        {
            return NetworkState.Unknown;
        }
        catch
        {
            return NetworkState.Offline;
        }
    }

    /// <inheritdoc/>
    public async Task<bool> IsOnlineAsync(CancellationToken cancellationToken = default)
    {
        using var cts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        cts.CancelAfter(TimeSpan.FromSeconds(3));

        // 并行探测多个端点，任一成功即返回 true
        var probeTasks = ProbeUrls.Select(url => ProbeEndpointAsync(url, cts.Token));

        try
        {
            var results = await Task.WhenAll(probeTasks);
            return results.Any(success => success);
        }
        catch (OperationCanceledException)
        {
            return false;
        }
        catch
        {
            return false;
        }
    }

    private static async Task<bool> ProbeEndpointAsync(string url, CancellationToken cancellationToken)
    {
        try
        {
            using var request = new HttpRequestMessage(HttpMethod.Head, url);
            using var response = await HttpClient.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, cancellationToken);
            return response.IsSuccessStatusCode;
        }
        catch
        {
            return false;
        }
    }
}
