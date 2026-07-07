using DevEnvInit.Core.Models;
using DevEnvInit.Core.Services;

namespace DevEnvInit.Services;

public sealed class SevenZipExtractionService : IArchiveExtractionService
{
    public Task ExtractPackageAsync(
        SoftwarePackage package,
        string targetDirectory,
        IProgress<double> progress,
        CancellationToken cancellationToken = default)
    {
        throw new NotImplementedException("7z extraction is intentionally not wired in phase 2.");
    }

    public Task CleanupTempFilesAsync(
        SoftwarePackage package,
        CancellationToken cancellationToken = default)
    {
        throw new NotImplementedException("7z cleanup is intentionally not wired in phase 2.");
    }
}
