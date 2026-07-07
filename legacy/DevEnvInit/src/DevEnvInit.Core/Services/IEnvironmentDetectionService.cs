using DevEnvInit.Core.Models;

namespace DevEnvInit.Core.Services;

public interface IEnvironmentDetectionService
{
    Task<EnvironmentSnapshot> DetectAsync(
        AppConfiguration configuration,
        CancellationToken cancellationToken = default);
}
