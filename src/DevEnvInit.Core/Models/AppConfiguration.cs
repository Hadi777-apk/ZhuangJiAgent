namespace DevEnvInit.Core.Models;

public sealed record AppConfiguration(
    AppSettings Settings,
    IReadOnlyList<SoftwarePackage> Apps);

public sealed record AppSettings(
    string ProductName,
    string Version,
    int InstallTimeoutMinutes,
    InstallLocationPolicy InstallLocationPolicy);

public sealed record InstallLocationPolicy(
    bool Enabled,
    bool PreferCustomDir,
    string DefaultInstallRoot,
    bool FallbackToDefault,
    int MinSystemDriveFreeGB,
    int WarnIfSystemDriveFreeBelowGB,
    bool CreateInstallRootIfMissing,
    bool PreviewOnly);
