using DevEnvInit.Core.Models;

namespace DevEnvInit.Services.Tests;

public sealed class StubServiceTests
{
    [Fact]
    public async Task SevenZipExtractionService_fails_explicitly_in_phase_2()
    {
        var service = new SevenZipExtractionService();

        var error = await Assert.ThrowsAsync<NotImplementedException>(() =>
            service.ExtractPackageAsync(TestPackages.Create(), Path.GetTempPath(), new Progress<double>()));

        Assert.Contains("phase 2", error.Message);
    }

    [Fact]
    public async Task PowerShellInstallerService_returns_failure_for_missing_installer()
    {
        var service = new PowerShellInstallerService();
        var progress = new Progress<InstallProgress>();

        var result = await service.InstallAsync(
            TestPackages.Create("Missing Installer"),
            Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString("N")),
            null,
            progress);

        Assert.Equal(InstallStatus.Failed, result.Status);
        Assert.Contains("not found", result.Message, StringComparison.OrdinalIgnoreCase);
    }
}
