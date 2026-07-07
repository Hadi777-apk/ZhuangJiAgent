using System.Net.NetworkInformation;
using System.Runtime.InteropServices;
using System.Runtime.Versioning;
using System.Security.Principal;
using DevEnvInit.Core.Models;
using DevEnvInit.Core.Services;

namespace DevEnvInit.Services;

public sealed class WindowsEnvironmentDetectionService : IEnvironmentDetectionService
{
    private readonly string _repositoryRoot;

    public WindowsEnvironmentDetectionService(string repositoryRoot)
    {
        _repositoryRoot = string.IsNullOrWhiteSpace(repositoryRoot)
            ? throw new ArgumentException("Repository root is required.", nameof(repositoryRoot))
            : repositoryRoot;
    }

    public Task<EnvironmentSnapshot> DetectAsync(
        AppConfiguration configuration,
        CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();

        var results = configuration.Apps
            .Where(app => app.Enabled)
            .Select(DetectPackageSafely)
            .ToArray();

        return Task.FromResult(new EnvironmentSnapshot(
            IsAdministrator: OperatingSystem.IsWindows() && IsAdministrator(),
            WindowsVersion: Environment.OSVersion.VersionString,
            Architecture: RuntimeInformation.OSArchitecture.ToString(),
            IsNetworkAvailable: NetworkInterface.GetIsNetworkAvailable(),
            SystemDriveFreeBytes: GetSystemDriveFreeBytes(),
            DetectionResults: results));
    }

    private DetectionResult DetectPackageSafely(SoftwarePackage package)
    {
        try
        {
            return DetectPackage(package);
        }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException or ArgumentException or NotSupportedException)
        {
            return new DetectionResult(package.Name, DetectionStatus.Error, null, null, "Detection failed for this package. Check configured paths and installer metadata.");
        }
    }

    private DetectionResult DetectPackage(SoftwarePackage package)
    {
        var detectedPath = package.InstallPaths
            .Select(ExpandPath)
            .FirstOrDefault(PathExists);

        if (!string.IsNullOrWhiteSpace(detectedPath))
        {
            return new DetectionResult(package.Name, DetectionStatus.Installed, null, detectedPath, "Detected by configured install path.");
        }

        if (!package.Installable)
        {
            return new DetectionResult(package.Name, DetectionStatus.NotInstallable, null, null, "Managed by another package or not directly installable.");
        }

        var installerPath = GetInstallerPath(package.Installer);
        if (installerPath is null || !File.Exists(installerPath))
        {
            return new DetectionResult(package.Name, DetectionStatus.InstallerMissing, null, null, "Local installer file is missing.");
        }

        if (package.RequireManualConfirmBeforeInstall || package.InstallLocationPolicy == "manual_confirm")
        {
            return new DetectionResult(package.Name, DetectionStatus.RequiresManualConfirmation, null, null, "Installer is available but requires manual confirmation.");
        }

        return new DetectionResult(package.Name, DetectionStatus.Missing, null, null, "Not detected; local installer is available.");
    }

    private string? GetInstallerPath(string installer)
    {
        if (string.IsNullOrWhiteSpace(installer) || Path.IsPathFullyQualified(installer))
        {
            return null;
        }

        var installersRoot = Path.GetFullPath(Path.Combine(_repositoryRoot, "installers"));
        var candidate = Path.GetFullPath(Path.Combine(installersRoot, installer));
        var requiredPrefix = installersRoot.EndsWith(Path.DirectorySeparatorChar)
            ? installersRoot
            : installersRoot + Path.DirectorySeparatorChar;

        return candidate.StartsWith(requiredPrefix, StringComparison.OrdinalIgnoreCase)
            ? candidate
            : null;
    }

    [SupportedOSPlatform("windows")]
    private static bool IsAdministrator()
    {
        using var identity = WindowsIdentity.GetCurrent();
        var principal = new WindowsPrincipal(identity);
        return principal.IsInRole(WindowsBuiltInRole.Administrator);
    }

    private static long GetSystemDriveFreeBytes()
    {
        var systemRoot = Path.GetPathRoot(Environment.GetFolderPath(Environment.SpecialFolder.System));
        if (string.IsNullOrWhiteSpace(systemRoot))
        {
            return 0;
        }

        var drive = new DriveInfo(systemRoot);
        return drive.IsReady ? drive.AvailableFreeSpace : 0;
    }

    private static string ExpandPath(string path) => Environment.ExpandEnvironmentVariables(path);

    private static bool PathExists(string path)
    {
        if (path.Contains('*', StringComparison.Ordinal))
        {
            return WildcardPathExists(path);
        }

        return File.Exists(path) || Directory.Exists(path);
    }

    private static bool WildcardPathExists(string path)
    {
        var directory = Path.GetDirectoryName(path);
        var pattern = Path.GetFileName(path);
        if (string.IsNullOrWhiteSpace(directory) || string.IsNullOrWhiteSpace(pattern) || !Directory.Exists(directory))
        {
            return false;
        }

        try
        {
            return Directory.EnumerateFileSystemEntries(directory, pattern).Any();
        }
        catch (UnauthorizedAccessException)
        {
            return false;
        }
    }
}
