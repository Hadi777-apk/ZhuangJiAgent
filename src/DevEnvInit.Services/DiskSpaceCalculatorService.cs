using DevEnvInit.Core.Models;
using DevEnvInit.Core.Services;

namespace DevEnvInit.Services;

public sealed class DiskSpaceCalculatorService : IDiskSpaceCalculatorService
{
    public Task<DiskSpaceEstimate> EstimateAsync(
        IReadOnlyList<SoftwarePackage> selectedPackages,
        string targetDirectory,
        CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();

        var root = Path.GetPathRoot(Path.GetFullPath(targetDirectory));
        var availableBytes = GetAvailableBytes(root);
        var hasEnoughSpace = availableBytes > 0;
        var message = hasEnoughSpace
            ? "Disk space information is available. Package size metadata is not available yet."
            : "Disk space information is unavailable for the selected target.";

        return Task.FromResult(new DiskSpaceEstimate(
            CompressedBytes: 0,
            PeakExtractedBytes: 0,
            AvailableBytes: availableBytes,
            HasEnoughSpace: hasEnoughSpace,
            Message: message));
    }

    private static long GetAvailableBytes(string? root)
    {
        if (string.IsNullOrWhiteSpace(root))
        {
            return 0;
        }

        var drive = new DriveInfo(root);
        return drive.IsReady ? drive.AvailableFreeSpace : 0;
    }
}
