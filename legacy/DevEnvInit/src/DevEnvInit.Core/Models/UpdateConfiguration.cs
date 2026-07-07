namespace DevEnvInit.Core.Models;

public sealed record UpdateConfiguration(
    UpdateSettings Settings,
    IReadOnlyList<UpdatePackage> Apps);

public sealed record UpdateSettings(
    string ProductName,
    string UpdateAgentVersion,
    bool ReadOnly,
    bool DownloadEnabled,
    bool UpgradeEnabled,
    bool RequireOfficialSource,
    int DownloadTimeoutMinutes);

public sealed record UpdatePackage(
    string Name,
    bool Enabled,
    string Category,
    string CurrentVersionDetect,
    string VersionCommand,
    IReadOnlyList<string> RegistryNames,
    IReadOnlyList<string> InstallPaths,
    string OfficialSourceType,
    string OfficialUrl,
    string DirectDownloadUrl,
    string GitHubRepo,
    string WingetId,
    string InstallerFileName,
    bool AllowAutoDownload,
    bool AllowAutoUpgrade,
    bool RequireUserConfirmBeforeUpgrade,
    IReadOnlyList<string> ConfigPaths,
    IReadOnlyList<string> ExcludePatterns,
    bool BackupBeforeUpgrade,
    string UpgradePolicy,
    string RiskLevel,
    string Notes,
    IReadOnlyList<string> AppxNames);
