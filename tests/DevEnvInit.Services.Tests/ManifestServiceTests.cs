namespace DevEnvInit.Services.Tests;

public sealed class ManifestServiceTests
{
    [Fact]
    public async Task LoadAppConfigurationAsync_reads_current_config_schema()
    {
        var service = new ManifestService(GetRepositoryRoot());

        var configuration = await service.LoadAppConfigurationAsync();

        Assert.Equal("AI 开发环境初始化工具", configuration.Settings.ProductName);
        Assert.Equal("D:\\AI-Environment-Apps", configuration.Settings.InstallLocationPolicy.DefaultInstallRoot);
        Assert.Contains(configuration.Apps, app => app.Name == "Python 3.12" && app.Installer == "python-3.12.exe");
        Assert.Contains(configuration.Apps, app => app.Name == "NPM" && app.Installable == false && app.ManagedBy == "Node LTS");
    }

    [Fact]
    public async Task LoadUpdateConfigurationAsync_reads_current_update_schema()
    {
        var service = new ManifestService(GetRepositoryRoot());

        var configuration = await service.LoadUpdateConfigurationAsync();

        Assert.True(configuration.Settings.ReadOnly);
        Assert.False(configuration.Settings.DownloadEnabled);
        Assert.Contains(configuration.Apps, app => app.Name == "OpenClaw" && app.OfficialSourceType == "github_release");
    }

    [Fact]
    public async Task LoadAllowlistAsync_reads_current_allowed_domains()
    {
        var service = new ManifestService(GetRepositoryRoot());

        var allowlist = await service.LoadAllowlistAsync();

        Assert.Contains("github.com", allowlist.AllowedDomains);
        Assert.Contains("direct_url", allowlist.Notes);
    }

    private static string GetRepositoryRoot()
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null && !File.Exists(Path.Combine(directory.FullName, "config.json")))
        {
            directory = directory.Parent;
        }

        return directory?.FullName ?? throw new InvalidOperationException("Repository root was not found.");
    }
}
