using DevEnvInit.Core.Models;

namespace DevEnvInit.Core.Services;

public interface IReportService
{
    Task<string> GenerateInstallReportAsync(
        IReadOnlyList<InstallResult> results,
        string outputDirectory,
        CancellationToken cancellationToken = default);
}
