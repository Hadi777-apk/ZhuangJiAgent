using DevEnvInit.Core.Models;

namespace DevEnvInit.Core.Services;

public interface IManifestService
{
    Task<AppConfiguration> LoadAppConfigurationAsync(CancellationToken cancellationToken = default);

    Task<UpdateConfiguration> LoadUpdateConfigurationAsync(CancellationToken cancellationToken = default);

    Task<AllowlistConfiguration> LoadAllowlistAsync(CancellationToken cancellationToken = default);
}
