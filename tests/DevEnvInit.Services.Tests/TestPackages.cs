using DevEnvInit.Core.Models;

namespace DevEnvInit.Services.Tests;

internal static class TestPackages
{
    public static SoftwarePackage Create(string name = "Git") =>
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
