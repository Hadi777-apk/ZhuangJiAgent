using DevEnvInit.Core.Models;
using DevEnvInit.Core.State;

namespace DevEnvInit.Core.Tests;

public sealed class InstallSessionStateTests
{
    [Fact]
    public void Empty_uses_safe_defaults()
    {
        var state = InstallSessionState.Empty;

        Assert.False(state.EnvironmentSnapshot.IsAdministrator);
        Assert.Empty(state.AvailablePackages);
        Assert.Empty(state.SelectedPackages);
        Assert.Empty(state.InstallResults);
        Assert.Equal(string.Empty, state.InstallRoot);
        Assert.Equal(string.Empty, state.DownloadDirectory);
        Assert.Equal(string.Empty, state.TempDirectory);
    }

    [Fact]
    public void WithSelectedPackages_returns_new_state_without_mutating_existing_state()
    {
        var original = InstallSessionState.Empty.WithAvailablePackages([CreatePackage("Git")]);
        var selected = new[] { CreatePackage("Python 3.12") };

        var updated = original.WithSelectedPackages(selected);

        Assert.Empty(original.SelectedPackages);
        Assert.Single(updated.SelectedPackages);
        Assert.Equal("Python 3.12", updated.SelectedPackages[0].Name);
        Assert.Single(updated.AvailablePackages);
    }

    [Fact]
    public void WithSelectedPackages_snapshots_caller_collection()
    {
        var selected = new List<SoftwarePackage> { CreatePackage("Git") };
        var state = InstallSessionState.Empty.WithSelectedPackages(selected);

        selected.Add(CreatePackage("Node LTS"));

        Assert.Single(state.SelectedPackages);
        Assert.Equal("Git", state.SelectedPackages[0].Name);
    }

    [Fact]
    public void WithEnvironmentSnapshot_preserves_selection_and_paths()
    {
        var original = InstallSessionState.Empty
            .WithSelectedPackages([CreatePackage("Node LTS")])
            .WithPaths("D:\\Apps", "D:\\Downloads", "D:\\Temp");
        var snapshot = new EnvironmentSnapshot(
            IsAdministrator: true,
            WindowsVersion: "Windows 11",
            Architecture: "ARM64",
            IsNetworkAvailable: true,
            SystemDriveFreeBytes: 42,
            DetectionResults: Array.Empty<DetectionResult>());

        var updated = original.WithEnvironmentSnapshot(snapshot);

        Assert.True(updated.EnvironmentSnapshot.IsAdministrator);
        Assert.Single(updated.SelectedPackages);
        Assert.Equal("D:\\Apps", updated.InstallRoot);
        Assert.Equal("D:\\Downloads", updated.DownloadDirectory);
        Assert.Equal("D:\\Temp", updated.TempDirectory);
    }

    [Fact]
    public void AddInstallResult_appends_result_without_clearing_existing_results()
    {
        var first = new InstallResult("Git", InstallStatus.Succeeded, "Installed", null);
        var second = new InstallResult("Node LTS", InstallStatus.Failed, "Installer failed", "logs/node.log");
        var original = InstallSessionState.Empty.AddInstallResult(first);

        var updated = original.AddInstallResult(second);

        Assert.Single(original.InstallResults);
        Assert.Equal(2, updated.InstallResults.Count);
        Assert.Equal("Git", updated.InstallResults[0].PackageName);
        Assert.Equal("Node LTS", updated.InstallResults[1].PackageName);
    }

    private static SoftwarePackage CreatePackage(string name) =>
        new(
            Name: name,
            Installer: string.Empty,
            Type: "exe",
            RequiredVersion: string.Empty,
            TargetMajorVersion: null,
            CheckCommands: Array.Empty<string>(),
            RegistryNames: Array.Empty<string>(),
            InstallPaths: Array.Empty<string>(),
            SilentArgs: Array.Empty<string>(),
            FallbackArgs: Array.Empty<string>(),
            VersionCommand: string.Empty,
            Enabled: true,
            ForceUpgradeWhenVersionUnknown: false,
            Installable: true,
            SupportCustomInstallDir: false,
            CustomInstallDir: string.Empty,
            InstallDirArgsTemplate: string.Empty,
            InstallLocationRisk: string.Empty,
            InstallLocationPolicy: string.Empty,
            InstallLocationNotes: string.Empty,
            AppxNames: Array.Empty<string>(),
            ProcessNames: Array.Empty<string>(),
            ShortcutNames: Array.Empty<string>(),
            RegistryExcludeNames: Array.Empty<string>(),
            InstallerKind: null,
            OfflineInstallSupported: false,
            RequiresNetwork: false,
            RequiresStoreInstaller: false,
            AutoInstallEnabled: false,
            RequireManualConfirmBeforeInstall: false,
            RefreshPathAfterInstall: false,
            ManagedBy: null,
            TimeoutMinutes: null);
}
