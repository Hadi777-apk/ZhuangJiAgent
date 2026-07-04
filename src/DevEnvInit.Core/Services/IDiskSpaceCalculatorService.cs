using DevEnvInit.Core.Models;

namespace DevEnvInit.Core.Services;

public interface IDiskSpaceCalculatorService
{
    Task<DiskSpaceEstimate> EstimateAsync(
        IReadOnlyList<SoftwarePackage> selectedPackages,
        string targetDirectory,
        CancellationToken cancellationToken = default);
}
