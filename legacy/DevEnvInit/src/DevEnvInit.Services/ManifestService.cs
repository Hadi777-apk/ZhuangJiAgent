using System.Text.Json;
using DevEnvInit.Core.Models;
using DevEnvInit.Core.Services;

namespace DevEnvInit.Services;

public sealed class ManifestService : IManifestService
{
    private readonly string _appConfigPath;
    private readonly string _updateConfigPath;
    private readonly string _allowlistPath;

    public ManifestService(string repositoryRoot)
    {
        if (string.IsNullOrWhiteSpace(repositoryRoot))
        {
            throw new ArgumentException("Repository root is required.", nameof(repositoryRoot));
        }

        _appConfigPath = Path.Combine(repositoryRoot, "config.json");
        _updateConfigPath = Path.Combine(repositoryRoot, "update-config.json");
        _allowlistPath = Path.Combine(repositoryRoot, "sources", "allowlist.json");
    }

    public async Task<AppConfiguration> LoadAppConfigurationAsync(CancellationToken cancellationToken = default)
    {
        using var document = await LoadJsonAsync(_appConfigPath, cancellationToken);
        var root = document.RootElement;
        var settingsElement = root.RequireProperty("settings");
        var installPolicyElement = settingsElement.RequireProperty("installLocationPolicy");

        var settings = new AppSettings(
            ProductName: settingsElement.GetStringOrDefault("productName"),
            Version: settingsElement.GetStringOrDefault("version"),
            InstallTimeoutMinutes: settingsElement.GetInt32OrDefault("installTimeoutMinutes"),
            InstallLocationPolicy: new InstallLocationPolicy(
                Enabled: installPolicyElement.GetBooleanOrDefault("enabled"),
                PreferCustomDir: installPolicyElement.GetBooleanOrDefault("preferCustomDir"),
                DefaultInstallRoot: installPolicyElement.GetStringOrDefault("defaultInstallRoot"),
                FallbackToDefault: installPolicyElement.GetBooleanOrDefault("fallbackToDefault"),
                MinSystemDriveFreeGB: installPolicyElement.GetInt32OrDefault("minSystemDriveFreeGB"),
                WarnIfSystemDriveFreeBelowGB: installPolicyElement.GetInt32OrDefault("warnIfSystemDriveFreeBelowGB"),
                CreateInstallRootIfMissing: installPolicyElement.GetBooleanOrDefault("createInstallRootIfMissing"),
                PreviewOnly: installPolicyElement.GetBooleanOrDefault("previewOnly")));

        var apps = root.RequireProperty("apps")
            .EnumerateArray()
            .Select(ReadSoftwarePackage)
            .ToArray();

        return new AppConfiguration(settings, apps);
    }

    public async Task<UpdateConfiguration> LoadUpdateConfigurationAsync(CancellationToken cancellationToken = default)
    {
        using var document = await LoadJsonAsync(_updateConfigPath, cancellationToken);
        var root = document.RootElement;
        var settingsElement = root.RequireProperty("settings");
        var settings = new UpdateSettings(
            ProductName: settingsElement.GetStringOrDefault("productName"),
            UpdateAgentVersion: settingsElement.GetStringOrDefault("updateAgentVersion"),
            ReadOnly: settingsElement.GetBooleanOrDefault("readOnly"),
            DownloadEnabled: settingsElement.GetBooleanOrDefault("downloadEnabled"),
            UpgradeEnabled: settingsElement.GetBooleanOrDefault("upgradeEnabled"),
            RequireOfficialSource: settingsElement.GetBooleanOrDefault("requireOfficialSource"),
            DownloadTimeoutMinutes: settingsElement.GetInt32OrDefault("downloadTimeoutMinutes"));

        var apps = root.RequireProperty("apps")
            .EnumerateArray()
            .Select(ReadUpdatePackage)
            .ToArray();

        return new UpdateConfiguration(settings, apps);
    }

    public async Task<AllowlistConfiguration> LoadAllowlistAsync(CancellationToken cancellationToken = default)
    {
        using var document = await LoadJsonAsync(_allowlistPath, cancellationToken);
        var root = document.RootElement;
        return new AllowlistConfiguration(
            AllowedDomains: root.GetStringArrayOrEmpty("allowedDomains"),
            Notes: root.GetStringOrDefault("notes"));
    }

    private static async Task<JsonDocument> LoadJsonAsync(string path, CancellationToken cancellationToken)
    {
        if (!File.Exists(path))
        {
            throw new FileNotFoundException("Configuration file was not found.", path);
        }

        await using var stream = File.OpenRead(path);
        return await JsonDocument.ParseAsync(stream, cancellationToken: cancellationToken);
    }

    private static SoftwarePackage ReadSoftwarePackage(JsonElement app) =>
        new(
            Name: app.GetStringOrDefault("name"),
            Installer: app.GetStringOrDefault("installer"),
            Type: app.GetStringOrDefault("type"),
            RequiredVersion: app.GetStringOrDefault("requiredVersion"),
            TargetMajorVersion: app.GetNullableInt32("targetMajorVersion"),
            CheckCommands: app.GetStringArrayOrEmpty("checkCommands"),
            RegistryNames: app.GetStringArrayOrEmpty("registryNames"),
            InstallPaths: app.GetStringArrayOrEmpty("installPaths"),
            SilentArgs: app.GetStringArrayOrEmpty("silentArgs"),
            FallbackArgs: app.GetStringArrayOrEmpty("fallbackArgs"),
            VersionCommand: app.GetStringOrDefault("versionCommand"),
            Enabled: app.GetBooleanOrDefault("enabled"),
            ForceUpgradeWhenVersionUnknown: app.GetBooleanOrDefault("forceUpgradeWhenVersionUnknown"),
            Installable: app.GetBooleanOrDefault("installable"),
            SupportCustomInstallDir: app.GetBooleanOrDefault("supportCustomInstallDir"),
            CustomInstallDir: app.GetStringOrDefault("customInstallDir"),
            InstallDirArgsTemplate: app.GetStringOrDefault("installDirArgsTemplate"),
            InstallLocationRisk: app.GetStringOrDefault("installLocationRisk"),
            InstallLocationPolicy: app.GetStringOrDefault("installLocationPolicy"),
            InstallLocationNotes: app.GetStringOrDefault("installLocationNotes"),
            AppxNames: app.GetStringArrayOrEmpty("appxNames"),
            ProcessNames: app.GetStringArrayOrEmpty("processNames"),
            ShortcutNames: app.GetStringArrayOrEmpty("shortcutNames"),
            RegistryExcludeNames: app.GetStringArrayOrEmpty("registryExcludeNames"),
            InstallerKind: app.GetNullableString("installerKind"),
            OfflineInstallSupported: app.GetBooleanOrDefault("offlineInstallSupported"),
            RequiresNetwork: app.GetBooleanOrDefault("requiresNetwork"),
            RequiresStoreInstaller: app.GetBooleanOrDefault("requiresStoreInstaller"),
            AutoInstallEnabled: app.GetBooleanOrDefault("autoInstallEnabled"),
            RequireManualConfirmBeforeInstall: app.GetBooleanOrDefault("requireManualConfirmBeforeInstall"),
            RefreshPathAfterInstall: app.GetBooleanOrDefault("refreshPathAfterInstall"),
            ManagedBy: app.GetNullableString("managedBy"),
            TimeoutMinutes: app.GetNullableInt32("timeoutMinutes"));

    private static UpdatePackage ReadUpdatePackage(JsonElement app) =>
        new(
            Name: app.GetStringOrDefault("name"),
            Enabled: app.GetBooleanOrDefault("enabled"),
            Category: app.GetStringOrDefault("category"),
            CurrentVersionDetect: app.GetStringOrDefault("currentVersionDetect"),
            VersionCommand: app.GetStringOrDefault("versionCommand"),
            RegistryNames: app.GetStringArrayOrEmpty("registryNames"),
            InstallPaths: app.GetStringArrayOrEmpty("installPaths"),
            OfficialSourceType: app.GetStringOrDefault("officialSourceType"),
            OfficialUrl: app.GetStringOrDefault("officialUrl"),
            DirectDownloadUrl: app.GetStringOrDefault("directDownloadUrl"),
            GitHubRepo: app.GetStringOrDefault("githubRepo"),
            WingetId: app.GetStringOrDefault("wingetId"),
            InstallerFileName: app.GetStringOrDefault("installerFileName"),
            AllowAutoDownload: app.GetBooleanOrDefault("allowAutoDownload"),
            AllowAutoUpgrade: app.GetBooleanOrDefault("allowAutoUpgrade"),
            RequireUserConfirmBeforeUpgrade: app.GetBooleanOrDefault("requireUserConfirmBeforeUpgrade"),
            ConfigPaths: app.GetStringArrayOrEmpty("configPaths"),
            ExcludePatterns: app.GetStringArrayOrEmpty("excludePatterns"),
            BackupBeforeUpgrade: app.GetBooleanOrDefault("backupBeforeUpgrade"),
            UpgradePolicy: app.GetStringOrDefault("upgradePolicy"),
            RiskLevel: app.GetStringOrDefault("riskLevel"),
            Notes: app.GetStringOrDefault("notes"),
            AppxNames: app.GetStringArrayOrEmpty("appxNames"));
}
