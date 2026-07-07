using System.Security.Cryptography;
using DevEnvInit.Core.Models;
using DevEnvInit.Core.Services;

namespace DevEnvInit.Services;

public sealed class HashVerificationService : IHashVerificationService
{
    public async Task<VerificationResult> VerifyAsync(
        SoftwarePackage package,
        string installerPath,
        CancellationToken cancellationToken = default)
    {
        if (!File.Exists(installerPath))
        {
            return new VerificationResult(package.Name, false, null, null, "Installer file was not found.");
        }

        await using var stream = File.OpenRead(installerPath);
        var hash = await SHA256.HashDataAsync(stream, cancellationToken);
        var actual = Convert.ToHexString(hash).ToLowerInvariant();

        return new VerificationResult(package.Name, true, null, actual, "SHA256 calculated.");
    }
}
