using System.Diagnostics;
using System.IO;
using ZhuangJiAgent.Models;

namespace ZhuangJiAgent.Services;

/// <summary>
/// 安装服务实现
/// </summary>
public sealed class InstallService : IInstallService
{
    private readonly IDetectionService _detectionService;

    public InstallService(IDetectionService detectionService)
    {
        _detectionService = detectionService;
    }

    /// <inheritdoc/>
    public async Task<InstallResult> InstallPackageAsync(
        SoftwarePackage package,
        string installerPath,
        CancellationToken cancellationToken = default)
    {
        var startTime = DateTime.UtcNow;

        try
        {
            // 验证安装程序存在
            if (!File.Exists(installerPath))
            {
                return new InstallResult
                {
                    Success = false,
                    PackageId = package.Id,
                    Status = InstallStatus.Failed,
                    ErrorMessage = $"安装程序不存在: {installerPath}"
                };
            }

            // 根据安装程序类型执行安装
            var exitCode = package.Installer.Type switch
            {
                InstallerType.Winget => await InstallViaWingetAsync(package, cancellationToken),
                InstallerType.Exe => await InstallExeAsync(installerPath, package.Installer.SilentArgs, cancellationToken),
                InstallerType.Msi => await InstallMsiAsync(installerPath, package.Installer.SilentArgs, cancellationToken),
                InstallerType.Msix => await InstallMsixAsync(installerPath, cancellationToken),
                _ => throw new NotSupportedException($"不支持的安装程序类型: {package.Installer.Type}")
            };

            var elapsed = (DateTime.UtcNow - startTime).TotalSeconds;

            // Winget 3010 退出码表示需要重启，但安装成功
            var isSuccess = exitCode == 0 || (package.Installer.Type == InstallerType.Winget && exitCode == 3010);
            var requiresReboot = exitCode == 3010;

            if (!isSuccess)
            {
                return new InstallResult
                {
                    Success = false,
                    PackageId = package.Id,
                    Status = InstallStatus.Failed,
                    ErrorMessage = $"安装失败，退出码: {exitCode}",
                    ExitCode = exitCode,
                    ElapsedSeconds = elapsed
                };
            }

            // 重新检测确认安装成功
            var isInstalled = await _detectionService.IsInstalledAsync(package, cancellationToken);

            return new InstallResult
            {
                Success = isInstalled,
                PackageId = package.Id,
                Status = isInstalled ? InstallStatus.Success : InstallStatus.Failed,
                ErrorMessage = isInstalled ? null : "安装后检测未通过",
                ExitCode = exitCode,
                ElapsedSeconds = elapsed,
                RequiresReboot = requiresReboot
            };
        }
        catch (OperationCanceledException)
        {
            var elapsed = (DateTime.UtcNow - startTime).TotalSeconds;
            return new InstallResult
            {
                Success = false,
                PackageId = package.Id,
                Status = InstallStatus.Cancelled,
                ErrorMessage = "安装已取消",
                ElapsedSeconds = elapsed
            };
        }
        catch (Exception ex)
        {
            var elapsed = (DateTime.UtcNow - startTime).TotalSeconds;
            return new InstallResult
            {
                Success = false,
                PackageId = package.Id,
                Status = InstallStatus.Failed,
                ErrorMessage = ex.Message,
                ElapsedSeconds = elapsed
            };
        }
    }

    /// <inheritdoc/>
    public async Task<List<InstallResult>> InstallPackagesAsync(
        IEnumerable<SoftwarePackage> packages,
        Dictionary<string, string> installerPaths,
        CancellationToken cancellationToken = default)
    {
        var results = new List<InstallResult>();

        // 按 Order 排序，顺序安装（考虑依赖关系）
        var sortedPackages = packages.OrderBy(p => p.Order).ToList();

        foreach (var package in sortedPackages)
        {
            if (!installerPaths.TryGetValue(package.Id, out var installerPath))
            {
                results.Add(new InstallResult
                {
                    Success = false,
                    PackageId = package.Id,
                    Status = InstallStatus.Failed,
                    ErrorMessage = "未找到安装程序路径"
                });
                continue;
            }

            var result = await CheckAndInstallAsync(package, installerPath, cancellationToken);
            results.Add(result);

            if (result.Status == InstallStatus.Cancelled)
                break;
        }

        return results;
    }

    /// <inheritdoc/>
    public async Task<InstallResult> CheckAndInstallAsync(
        SoftwarePackage package,
        string installerPath,
        CancellationToken cancellationToken = default)
    {
        // 检测是否已安装
        var isInstalled = await _detectionService.IsInstalledAsync(package, cancellationToken);

        if (isInstalled)
        {
            // 检查版本是否匹配
            var isVersionMatch = await _detectionService.IsVersionMatchAsync(package, cancellationToken);

            if (isVersionMatch)
            {
                return new InstallResult
                {
                    Success = true,
                    PackageId = package.Id,
                    Status = InstallStatus.AlreadyInstalled,
                    ElapsedSeconds = 0
                };
            }
        }

        // 未安装或版本不匹配，执行安装
        return await InstallPackageAsync(package, installerPath, cancellationToken);
    }

    private static async Task<int> InstallExeAsync(string installerPath, string silentArgs, CancellationToken cancellationToken)
    {
        var psi = new ProcessStartInfo
        {
            FileName = installerPath,
            Arguments = silentArgs,
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true
        };

        using var process = Process.Start(psi);
        if (process is null)
            throw new InvalidOperationException("无法启动安装程序");

        try
        {
            // 异步读取输出防止死锁，必须 await 否则缓冲区写满会阻塞进程
            var outputTask = process.StandardOutput.ReadToEndAsync(cancellationToken);
            var errorTask = process.StandardError.ReadToEndAsync(cancellationToken);

            await process.WaitForExitAsync(cancellationToken);
            await outputTask;
            await errorTask;

            return process.ExitCode;
        }
        catch (OperationCanceledException)
        {
            TryKillProcess(process);
            throw;
        }
    }

    private static async Task<int> InstallMsiAsync(string installerPath, string silentArgs, CancellationToken cancellationToken)
    {
        var arguments = $"/i \"{installerPath}\" /qn /norestart {silentArgs}".Trim();

        var psi = new ProcessStartInfo
        {
            FileName = "msiexec.exe",
            Arguments = arguments,
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true
        };

        using var process = Process.Start(psi);
        if (process is null)
            throw new InvalidOperationException("无法启动 msiexec");

        try
        {
            var outputTask = process.StandardOutput.ReadToEndAsync(cancellationToken);
            var errorTask = process.StandardError.ReadToEndAsync(cancellationToken);

            await process.WaitForExitAsync(cancellationToken);
            await outputTask;
            await errorTask;

            return process.ExitCode;
        }
        catch (OperationCanceledException)
        {
            TryKillProcess(process);
            throw;
        }
    }

    private static async Task<int> InstallMsixAsync(string installerPath, CancellationToken cancellationToken)
    {
        // 用单引号包裹路径并通过 -LiteralPath 避免 installerPath 含单引号时的 PowerShell 注入。
        var psi = new ProcessStartInfo
        {
            FileName = "powershell.exe",
            Arguments = $"-NoProfile -Command \"Add-AppxPackage -LiteralPath '{installerPath}'\"",
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true
        };

        using var process = Process.Start(psi);
        if (process is null)
            throw new InvalidOperationException("无法启动 PowerShell");

        try
        {
            var outputTask = process.StandardOutput.ReadToEndAsync(cancellationToken);
            var errorTask = process.StandardError.ReadToEndAsync(cancellationToken);

            await process.WaitForExitAsync(cancellationToken);
            await outputTask;
            await errorTask;

            return process.ExitCode;
        }
        catch (OperationCanceledException)
        {
            TryKillProcess(process);
            throw;
        }
    }

    private static async Task<int> InstallViaWingetAsync(SoftwarePackage package, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(package.Installer.WingetId))
            throw new InvalidOperationException("Winget 安装需要指定 WingetId");

        // 校验 WingetId 仅含安全字符，避免 manifest 被篡改时注入额外 winget 参数。
        var wingetId = package.Installer.WingetId;
        if (!IsValidWingetId(wingetId))
            throw new InvalidOperationException($"非法 WingetId: {wingetId}");

        var psi = new ProcessStartInfo
        {
            FileName = "winget",
            Arguments = $"install --id {wingetId} --silent --accept-package-agreements --accept-source-agreements",
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true
        };

        using var process = Process.Start(psi);
        if (process is null)
            throw new InvalidOperationException("无法启动 winget");

        try
        {
            var outputTask = process.StandardOutput.ReadToEndAsync(cancellationToken);
            var errorTask = process.StandardError.ReadToEndAsync(cancellationToken);

            await process.WaitForExitAsync(cancellationToken);
            await outputTask;
            await errorTask;

            return process.ExitCode;
        }
        catch (OperationCanceledException)
        {
            TryKillProcess(process);
            throw;
        }
    }

    private static bool IsValidWingetId(string id)
    {
        // WingetId 形如Publisher.Package，允许字母数字、点、连字符、下划线。
        if (string.IsNullOrWhiteSpace(id))
            return false;
        foreach (var c in id)
        {
            if (!(char.IsLetterOrDigit(c) || c == '.' || c == '-' || c == '_'))
                return false;
        }
        return true;
    }

    private static void TryKillProcess(Process process)
    {
        try
        {
            if (!process.HasExited)
                process.Kill(entireProcessTree: true);
        }
        catch
        {
            // 尽力清理，忽略 kill 失败
        }
    }
}