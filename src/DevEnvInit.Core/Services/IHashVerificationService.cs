using DevEnvInit.Core.Models;

namespace DevEnvInit.Core.Services;

public interface IHashVerificationService
{
    Task<VerificationResult> VerifyAsync(
        SoftwarePackage package,
        string installerPath,
        CancellationToken cancellationToken = default);
}
