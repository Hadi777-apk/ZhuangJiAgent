using DevEnvInit.Core.Models;
using DevEnvInit.Core.Services;

namespace DevEnvInit.Services;

public sealed class PowerShellInstallerService : IInstallerExecutionService
{
    public Task<InstallResult> InstallAsync(
        SoftwarePackage package,
        string installerPath,
        string? installDirectory,
        IProgress<InstallProgress> progress,
        CancellationToken cancellationToken = default)
    {
        throw new NotImplementedException("Installer execution is intentionally not wired in phase 2.");
    }
}
