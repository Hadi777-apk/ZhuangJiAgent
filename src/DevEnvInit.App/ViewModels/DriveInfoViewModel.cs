using System.IO;

namespace DevEnvInit.App.ViewModels;

public sealed class DriveInfoViewModel
{
    private readonly DriveInfo _drive;

    public DriveInfoViewModel(DriveInfo drive)
    {
        _drive = drive;
        AvailableFreeBytes = drive.AvailableFreeSpace;
    }

    public string Name => _drive.Name;

    public string VolumeLabel => string.IsNullOrWhiteSpace(_drive.VolumeLabel) ? "(无标签)" : _drive.VolumeLabel;

    public string TotalSize => FormatBytes(_drive.TotalSize);

    public long AvailableFreeBytes { get; }

    public string AvailableFree => FormatBytes(AvailableFreeBytes);

    public string RootDirectory => _drive.RootDirectory.FullName;

    private static string FormatBytes(long bytes) => bytes switch
    {
        >= 1L << 40 => $"{bytes / (double)(1L << 40):F1} TB",
        >= 1L << 30 => $"{bytes / (double)(1L << 30):F1} GB",
        >= 1L << 20 => $"{bytes / (double)(1L << 20):F1} MB",
        _ => $"{bytes} B"
    };
}
