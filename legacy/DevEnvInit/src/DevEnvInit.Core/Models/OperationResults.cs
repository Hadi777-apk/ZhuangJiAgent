namespace DevEnvInit.Core.Models;

public sealed record VerificationResult(
    string PackageName,
    bool IsValid,
    string? ExpectedSha256,
    string? ActualSha256,
    string Message);

public sealed record UpdateResult(
    string PackageName,
    string? CurrentVersion,
    string? LatestVersion,
    bool UpdateAvailable,
    string Suggestion,
    string Message);

public sealed record DownloadResult(
    string PackageName,
    bool Succeeded,
    string? FilePath,
    string Message);

public sealed record BackupRestoreResult(
    string PackageName,
    bool Succeeded,
    string? ManifestPath,
    string Message);
