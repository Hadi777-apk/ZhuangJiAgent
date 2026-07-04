using DevEnvInit.Core.Models;

namespace DevEnvInit.Services.Tests;

public sealed class WindowsEnvironmentDetectionServiceTests
{
    [Fact]
    public async Task DetectAsync_marks_missing_installer_without_running_installers()
    {
        var root = CreateRepositoryRoot();
        var service = new WindowsEnvironmentDetectionService(root);
        var configuration = CreateConfiguration(TestPackages.Create("Missing Tool") with
        {
            Installer = "missing.exe",
            InstallPaths = Array.Empty<string>()
        });

        try
        {
            var snapshot = await service.DetectAsync(configuration);

            var result = Assert.Single(snapshot.DetectionResults);
            Assert.Equal(DetectionStatus.InstallerMissing, result.Status);
        }
        finally
        {
            Directory.Delete(root, recursive: true);
        }
    }

    [Fact]
    public async Task DetectAsync_marks_installed_when_configured_path_exists()
    {
        var root = CreateRepositoryRoot();
        var installedFile = Path.Combine(root, "tool.exe");
        await File.WriteAllTextAsync(installedFile, string.Empty);
        var service = new WindowsEnvironmentDetectionService(root);
        var configuration = CreateConfiguration(TestPackages.Create("Existing Tool") with
        {
            Installer = "missing.exe",
            InstallPaths = [installedFile]
        });

        try
        {
            var snapshot = await service.DetectAsync(configuration);

            var result = Assert.Single(snapshot.DetectionResults);
            Assert.Equal(DetectionStatus.Installed, result.Status);
            Assert.Equal(installedFile, result.DetectedPath);
        }
        finally
        {
            Directory.Delete(root, recursive: true);
        }
    }

    [Fact]
    public async Task DetectAsync_rejects_installer_paths_outside_installers_directory()
    {
        var root = CreateRepositoryRoot();
        var outsideInstaller = Path.Combine(root, "outside.exe");
        await File.WriteAllTextAsync(outsideInstaller, string.Empty);
        var service = new WindowsEnvironmentDetectionService(root);
        var configuration = CreateConfiguration(TestPackages.Create("Unsafe Tool") with
        {
            Installer = "..\\outside.exe",
            InstallPaths = Array.Empty<string>()
        });

        try
        {
            var snapshot = await service.DetectAsync(configuration);

            var result = Assert.Single(snapshot.DetectionResults);
            Assert.Equal(DetectionStatus.InstallerMissing, result.Status);
        }
        finally
        {
            Directory.Delete(root, recursive: true);
        }
    }

    [Fact]
    public async Task DetectAsync_keeps_other_package_results_when_one_package_has_invalid_metadata()
    {
        var root = CreateRepositoryRoot();
        var existingTool = Path.Combine(root, "existing.exe");
        await File.WriteAllTextAsync(existingTool, string.Empty);
        var service = new WindowsEnvironmentDetectionService(root);
        var configuration = CreateConfiguration(
            TestPackages.Create("Bad Metadata Tool") with
            {
                Installer = "missing.exe",
                InstallPaths = [new string('x', 40000)]
            },
            TestPackages.Create("Existing Tool") with
            {
                Installer = "missing.exe",
                InstallPaths = [existingTool]
            });

        try
        {
            var snapshot = await service.DetectAsync(configuration);

            Assert.Equal(2, snapshot.DetectionResults.Count);
            Assert.Contains(snapshot.DetectionResults, result => result.PackageName == "Bad Metadata Tool" && result.Status is DetectionStatus.InstallerMissing or DetectionStatus.Error);
            Assert.Contains(snapshot.DetectionResults, result => result.PackageName == "Existing Tool" && result.Status == DetectionStatus.Installed);
        }
        finally
        {
            Directory.Delete(root, recursive: true);
        }
    }

    private static string CreateRepositoryRoot()
    {
        var root = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(Path.Combine(root, "installers"));
        return root;
    }

    private static AppConfiguration CreateConfiguration(SoftwarePackage package) =>
        new(
            Settings: new AppSettings(
                ProductName: "Test",
                Version: "1.0",
                InstallTimeoutMinutes: 1,
                InstallLocationPolicy: new InstallLocationPolicy(false, false, string.Empty, false, 0, 0, false, true)),
            Apps: [package]);

    private static AppConfiguration CreateConfiguration(SoftwarePackage first, SoftwarePackage second) =>
        new(
            Settings: new AppSettings(
                ProductName: "Test",
                Version: "1.0",
                InstallTimeoutMinutes: 1,
                InstallLocationPolicy: new InstallLocationPolicy(false, false, string.Empty, false, 0, 0, false, true)),
            Apps: [first, second]);
}
