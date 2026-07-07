using DevEnvInit.Core.Models;

namespace DevEnvInit.Core.Services;

public interface IArchiveExtractionService
{
    Task ExtractPackageAsync(
        SoftwarePackage package,
        string targetDirectory,
        IProgress<double> progress,
        CancellationToken cancellationToken = default);

    Task CleanupTempFilesAsync(
        SoftwarePackage package,
        CancellationToken cancellationToken = default);
}
