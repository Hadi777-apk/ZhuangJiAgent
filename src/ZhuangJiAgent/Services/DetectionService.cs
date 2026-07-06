using System.Diagnostics;
using System.IO;
using Microsoft.Win32;
using ZhuangJiAgent.Models;

namespace ZhuangJiAgent.Services;

/// <summary>
/// 软件检测服务实现
/// </summary>
public sealed class DetectionService : IDetectionService
{
    /// <inheritdoc/>
    public async Task<bool> IsInstalledAsync(SoftwarePackage package, CancellationToken cancellationToken = default)
    {
        if (package.Detection is null || package.Detection.Type == DetectionType.None)
            return false;

        return package.Detection.Type switch
        {
            DetectionType.Registry => await CheckRegistryAsync(package.Detection, cancellationToken),
            DetectionType.File => await CheckFileAsync(package.Detection, cancellationToken),
            DetectionType.Command => await CheckCommandAsync(package.Detection, cancellationToken),
            _ => false
        };
    }

    /// <inheritdoc/>
    public async Task<string?> GetInstalledVersionAsync(SoftwarePackage package, CancellationToken cancellationToken = default)
    {
        if (package.Detection is null || package.Detection.Type == DetectionType.None)
            return null;

        return package.Detection.Type switch
        {
            DetectionType.Registry => await GetRegistryVersionAsync(package.Detection, cancellationToken),
            DetectionType.Command => await GetCommandVersionAsync(package.Detection, cancellationToken),
            DetectionType.File => package.Detection.ExpectedVersion, // 文件检测无法获取版本
            _ => null
        };
    }

    /// <inheritdoc/>
    public async Task<bool> IsVersionMatchAsync(SoftwarePackage package, CancellationToken cancellationToken = default)
    {
        var installedVersion = await GetInstalledVersionAsync(package, cancellationToken);

        if (installedVersion is null)
            return false;

        if (package.Detection?.ExpectedVersion is null)
            return true;

        // 简单版本匹配（前缀匹配）
        return installedVersion.StartsWith(package.Detection.ExpectedVersion, StringComparison.OrdinalIgnoreCase);
    }

    private static Task<bool> CheckRegistryAsync(DetectionInfo detection, CancellationToken cancellationToken)
    {
        try
        {
            if (string.IsNullOrWhiteSpace(detection.RegistryKey))
                return Task.FromResult(false);

            var (hive, subKey) = ParseRegistryKey(detection.RegistryKey);
            using var key = hive?.OpenSubKey(subKey);

            if (key is null)
                return Task.FromResult(false);

            // 如果指定了值名称，检查该值是否存在
            if (!string.IsNullOrWhiteSpace(detection.RegistryValue))
            {
                var value = key.GetValue(detection.RegistryValue);
                return Task.FromResult(value is not null);
            }

            // 否则只检查键是否存在
            return Task.FromResult(true);
        }
        catch
        {
            return Task.FromResult(false);
        }
    }

    private static Task<bool> CheckFileAsync(DetectionInfo detection, CancellationToken cancellationToken)
    {
        try
        {
            if (string.IsNullOrWhiteSpace(detection.FilePath))
                return Task.FromResult(false);

            var expandedPath = Environment.ExpandEnvironmentVariables(detection.FilePath);
            return Task.FromResult(File.Exists(expandedPath));
        }
        catch
        {
            return Task.FromResult(false);
        }
    }

    private static async Task<bool> CheckCommandAsync(DetectionInfo detection, CancellationToken cancellationToken)
    {
        try
        {
            if (string.IsNullOrWhiteSpace(detection.Command))
                return false;

            var output = await ExecuteCommandAsync(detection.Command, cancellationToken);
            return !string.IsNullOrWhiteSpace(output);
        }
        catch
        {
            return false;
        }
    }

    private static Task<string?> GetRegistryVersionAsync(DetectionInfo detection, CancellationToken cancellationToken)
    {
        try
        {
            if (string.IsNullOrWhiteSpace(detection.RegistryKey))
                return Task.FromResult<string?>(null);

            var (hive, subKey) = ParseRegistryKey(detection.RegistryKey);
            using var key = hive?.OpenSubKey(subKey);

            if (key is null)
                return Task.FromResult<string?>(null);

            var valueName = detection.RegistryValue ?? "Version";
            var value = key.GetValue(valueName);

            return Task.FromResult(value?.ToString());
        }
        catch
        {
            return Task.FromResult<string?>(null);
        }
    }

    private static async Task<string?> GetCommandVersionAsync(DetectionInfo detection, CancellationToken cancellationToken)
    {
        try
        {
            if (string.IsNullOrWhiteSpace(detection.Command))
                return null;

            var output = await ExecuteCommandAsync(detection.Command, cancellationToken);
            return output?.Trim();
        }
        catch
        {
            return null;
        }
    }

    private static async Task<string?> ExecuteCommandAsync(string command, CancellationToken cancellationToken)
    {
        var psi = new ProcessStartInfo
        {
            FileName = "cmd.exe",
            Arguments = $"/c {command}",
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true
        };

        using var process = Process.Start(psi);
        if (process is null)
            return null;

        var outputTask = process.StandardOutput.ReadToEndAsync(cancellationToken);
        var errorTask = process.StandardError.ReadToEndAsync(cancellationToken);

        await process.WaitForExitAsync(cancellationToken);

        var output = await outputTask;
        var error = await errorTask;

        return process.ExitCode == 0 ? output : null;
    }

    private static (RegistryKey? Hive, string SubKey) ParseRegistryKey(string fullPath)
    {
        var parts = fullPath.Split('\\', 2);
        if (parts.Length < 2)
            return (null, string.Empty);

        var hive = parts[0].ToUpperInvariant() switch
        {
            "HKEY_LOCAL_MACHINE" or "HKLM" => Registry.LocalMachine,
            "HKEY_CURRENT_USER" or "HKCU" => Registry.CurrentUser,
            "HKEY_CLASSES_ROOT" or "HKCR" => Registry.ClassesRoot,
            "HKEY_USERS" => Registry.Users,
            "HKEY_CURRENT_CONFIG" => Registry.CurrentConfig,
            _ => null
        };

        return (hive, parts[1]);
    }
}
