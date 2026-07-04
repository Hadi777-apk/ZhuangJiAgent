using DevEnvInit.Core.Models;

namespace DevEnvInit.Core.State;

public sealed record InstallSessionState(
    EnvironmentSnapshot EnvironmentSnapshot,
    IReadOnlyList<SoftwarePackage> AvailablePackages,
    IReadOnlyList<SoftwarePackage> SelectedPackages,
    string InstallRoot,
    string DownloadDirectory,
    string TempDirectory,
    IReadOnlyList<InstallResult> InstallResults)
{
    public static InstallSessionState Empty { get; } = new(
        EnvironmentSnapshot: EnvironmentSnapshot.Empty,
        AvailablePackages: Array.Empty<SoftwarePackage>(),
        SelectedPackages: Array.Empty<SoftwarePackage>(),
        InstallRoot: string.Empty,
        DownloadDirectory: string.Empty,
        TempDirectory: string.Empty,
        InstallResults: Array.Empty<InstallResult>());

    public InstallSessionState WithEnvironmentSnapshot(EnvironmentSnapshot snapshot) =>
        this with { EnvironmentSnapshot = snapshot };

    public InstallSessionState WithAvailablePackages(IReadOnlyList<SoftwarePackage> packages) =>
        this with { AvailablePackages = packages.ToArray() };

    public InstallSessionState WithSelectedPackages(IReadOnlyList<SoftwarePackage> packages) =>
        this with { SelectedPackages = packages.ToArray() };

    public InstallSessionState WithPaths(string installRoot, string downloadDirectory, string tempDirectory) =>
        this with
        {
            InstallRoot = installRoot,
            DownloadDirectory = downloadDirectory,
            TempDirectory = tempDirectory
        };

    public InstallSessionState AddInstallResult(InstallResult result) =>
        this with { InstallResults = InstallResults.Concat(new[] { result }).ToArray() };
}
