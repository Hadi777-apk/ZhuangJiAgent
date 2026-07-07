namespace DevEnvInit.Core.Models;

public enum InstallStatus
{
    Pending,
    Extracting,
    Installing,
    CleaningUp,
    Succeeded,
    Skipped,
    Failed,
    Canceled
}

public sealed record InstallProgress(
    string PackageName,
    InstallStatus Status,
    double OverallPercent,
    string Message);

public sealed record InstallResult(
    string PackageName,
    InstallStatus Status,
    string Message,
    string? LogPath);
