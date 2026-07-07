namespace DevEnvInit.Core.Models;

public sealed record EnvironmentSnapshot(
    bool IsAdministrator,
    string WindowsVersion,
    string Architecture,
    bool IsNetworkAvailable,
    long SystemDriveFreeBytes,
    IReadOnlyList<DetectionResult> DetectionResults)
{
    public static EnvironmentSnapshot Empty { get; } = new(
        IsAdministrator: false,
        WindowsVersion: string.Empty,
        Architecture: string.Empty,
        IsNetworkAvailable: false,
        SystemDriveFreeBytes: 0,
        DetectionResults: Array.Empty<DetectionResult>());
}
