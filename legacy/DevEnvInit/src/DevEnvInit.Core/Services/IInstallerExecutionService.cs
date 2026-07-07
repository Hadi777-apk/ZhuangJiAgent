using DevEnvInit.Core.Models;

namespace DevEnvInit.Core.Services;

public interface IInstallerExecutionService
{
    Task<InstallResult> InstallAsync(
        SoftwarePackage package,
        string installerPath,
        string? installDirectory,
        IProgress<InstallProgress> progress,
        CancellationToken cancellationToken = default);
}
