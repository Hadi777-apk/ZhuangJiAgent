namespace DevEnvInit.Core.Models;

public sealed record InstallPlan(
    IReadOnlyList<SoftwarePackage> Packages,
    string InstallRoot,
    string DownloadDirectory,
    string TempDirectory,
    DiskSpaceEstimate DiskSpaceEstimate);

public sealed record DiskSpaceEstimate(
    long CompressedBytes,
    long PeakExtractedBytes,
    long AvailableBytes,
    bool HasEnoughSpace,
    string Message);
