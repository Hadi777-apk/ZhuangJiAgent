namespace DevEnvInit.Core.Models;

public enum DetectionStatus
{
    Unknown,
    Installed,
    Missing,
    NotInstallable,
    InstallerMissing,
    RequiresManualConfirmation,
    Error
}

public sealed record DetectionResult(
    string PackageName,
    DetectionStatus Status,
    string? InstalledVersion,
    string? DetectedPath,
    string Message);
