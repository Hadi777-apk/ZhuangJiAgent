using System.Collections.ObjectModel;
using System.IO;
using System.Windows.Input;
using DevEnvInit.Core.Models;
using DevEnvInit.Core.Services;
using DevEnvInit.Core.State;

namespace DevEnvInit.App.ViewModels;

public sealed class PathConfigViewModel : StepViewModel
{
    private readonly IDiskSpaceCalculatorService _diskSpaceService;
    private string _installRoot;
    private string _summary = "尚未检查磁盘空间。";
    private bool _isBusy;

    public PathConfigViewModel(IDiskSpaceCalculatorService diskSpaceService)
        : base("路径配置", "确认安装根目录、下载缓存目录和临时解压目录。")
    {
        _diskSpaceService = diskSpaceService;
        _installRoot = "D:\\AI-Environment-Apps";
        CheckSpaceCommand = new RelayCommand(async _ => await CheckSpaceAsync(), _ => !IsBusy);
    }

    public ObservableCollection<DriveInfoViewModel> Drives { get; } = new(
        DriveInfo.GetDrives()
            .Where(d => d.DriveType == DriveType.Fixed && d.IsReady)
            .Select(d => new DriveInfoViewModel(d))
            .OrderByDescending(d => d.AvailableFreeBytes));

    public string InstallRoot
    {
        get => _installRoot;
        set
        {
            if (SetProperty(ref _installRoot, value))
            {
                OnPropertyChanged(nameof(DownloadDirectory));
                OnPropertyChanged(nameof(TempDirectory));
            }
        }
    }

    public string DownloadDirectory => Path.Combine(InstallRoot, "downloads");

    public string TempDirectory => Path.Combine(InstallRoot, "temp");

    public ICommand CheckSpaceCommand { get; }

    public string Summary
    {
        get => _summary;
        private set => SetProperty(ref _summary, value);
    }

    public bool IsBusy
    {
        get => _isBusy;
        private set
        {
            if (SetProperty(ref _isBusy, value) && CheckSpaceCommand is RelayCommand command)
            {
                command.RaiseCanExecuteChanged();
            }
        }
    }

    public async Task CheckSpaceAsync()
    {
        IsBusy = true;
        Summary = "正在估算磁盘空间...";

        try
        {
            var estimate = await _diskSpaceService.EstimateAsync(Array.Empty<SoftwarePackage>(), InstallRoot);

            Summary = estimate.HasEnoughSpace
                ? $"C 盘可用：{FormatBytes(estimate.AvailableBytes)} · 空间充足。安装目录：{InstallRoot}"
                : $"C 盘可用：{FormatBytes(estimate.AvailableBytes)} · 请确认磁盘空间。";
        }
        catch (Exception error)
        {
            Summary = $"磁盘空间检查失败：{error.Message}";
        }
        finally
        {
            IsBusy = false;
        }
    }

    public void SyncToSession(InstallSessionState state)
    {
        state = state.WithPaths(InstallRoot, DownloadDirectory, TempDirectory);
    }

    private static string FormatBytes(long bytes) => bytes switch
    {
        >= 1L << 40 => $"{bytes >> 30 >> 10:F1} TB",
        >= 1L << 30 => $"{bytes / (double)(1L << 30):F1} GB",
        >= 1L << 20 => $"{bytes / (double)(1L << 20):F1} MB",
        _ => $"{bytes} B"
    };
}
