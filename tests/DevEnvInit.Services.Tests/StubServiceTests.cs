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
    public async Task PowerShellInstallerService_fails_explicitly_in_phase_2()
    {
        var service = new PowerShellInstallerService();

        var error = await Assert.ThrowsAsync<NotImplementedException>(() =>
            service.InstallAsync(
                TestPackages.Create(),
                "installer.exe",
                null,
                new Progress<InstallProgress>()));

        Assert.Contains("phase 2", error.Message);
    }
}
