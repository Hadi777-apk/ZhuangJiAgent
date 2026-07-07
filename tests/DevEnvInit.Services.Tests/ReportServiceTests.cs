using DevEnvInit.Core.Models;

namespace DevEnvInit.Services.Tests;

public sealed class ReportServiceTests
{
    [Fact]
    public async Task GenerateInstallReportAsync_writes_markdown_report()
    {
        var outputDirectory = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString("N"));
        var service = new ReportService();

        try
        {
            var reportPath = await service.GenerateInstallReportAsync(
                [new InstallResult("Git", InstallStatus.Succeeded, "Installed", "logs/git.log")],
                outputDirectory);

            Assert.True(File.Exists(reportPath));
            var content = await File.ReadAllTextAsync(reportPath);
            Assert.Contains("# Install Report", content);
            Assert.Contains("Git", content);
            Assert.Contains("Succeeded", content);
        }
        finally
        {
            if (Directory.Exists(outputDirectory))
            {
                Directory.Delete(outputDirectory, recursive: true);
            }
        }
    }
}
