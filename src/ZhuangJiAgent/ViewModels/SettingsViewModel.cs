using System.Windows.Input;
using ZhuangJiAgent.Models;
using ZhuangJiAgent.Services;

namespace ZhuangJiAgent.ViewModels;

/// <summary>
/// 设置页面 ViewModel
/// </summary>
public sealed class SettingsViewModel : ViewModelBase
{
    private readonly ISettingsService _settingsService;

    private bool _forceOfflineMode;
    private string _downloadDirectory = "downloads/cache";
    private int _maxConcurrentDownloads = 3;
    private bool _autoCheckUpdates = true;
    private string _remoteManifestUrl = string.Empty;
    private string _statusMessage = string.Empty;

    public SettingsViewModel(ISettingsService settingsService)
    {
        _settingsService = settingsService;

        SaveCommand = new RelayCommand(async () => await SaveSettingsAsync());
        ResetCommand = new RelayCommand(async () => await LoadSettingsAsync());
        BrowseFolderCommand = new RelayCommand(async () => { await Task.CompletedTask; BrowseFolder(); });
    }

    /// <summary>
    /// 强制离线模式
    /// </summary>
    public bool ForceOfflineMode
    {
        get => _forceOfflineMode;
        set => SetProperty(ref _forceOfflineMode, value);
    }

    /// <summary>
    /// 下载目录
    /// </summary>
    public string DownloadDirectory
    {
        get => _downloadDirectory;
        set => SetProperty(ref _downloadDirectory, value);
    }

    /// <summary>
    /// 并发下载数
    /// </summary>
    public int MaxConcurrentDownloads
    {
        get => _maxConcurrentDownloads;
        set => SetProperty(ref _maxConcurrentDownloads, Math.Clamp(value, 1, 5));
    }

    /// <summary>
    /// 启动时自动检查更新
    /// </summary>
    public bool AutoCheckUpdates
    {
        get => _autoCheckUpdates;
        set => SetProperty(ref _autoCheckUpdates, value);
    }

    /// <summary>
    /// 远程清单 URL
    /// </summary>
    public string RemoteManifestUrl
    {
        get => _remoteManifestUrl;
        set => SetProperty(ref _remoteManifestUrl, value);
    }

    /// <summary>
    /// 状态消息
    /// </summary>
    public string StatusMessage
    {
        get => _statusMessage;
        set => SetProperty(ref _statusMessage, value);
    }

    /// <summary>
    /// 保存命令
    /// </summary>
    public ICommand SaveCommand { get; }

    /// <summary>
    /// 重置命令
    /// </summary>
    public ICommand ResetCommand { get; }

    /// <summary>
    /// 浏览文件夹命令
    /// </summary>
    public ICommand BrowseFolderCommand { get; }

    /// <summary>
    /// 初始化加载设置
    /// </summary>
    public async Task InitializeAsync()
    {
        await LoadSettingsAsync();
    }

    private async Task LoadSettingsAsync()
    {
        try
        {
            var settings = await _settingsService.LoadSettingsAsync();

            ForceOfflineMode = settings.ForceOfflineMode;
            DownloadDirectory = settings.DownloadDirectory;
            MaxConcurrentDownloads = settings.MaxConcurrentDownloads;
            AutoCheckUpdates = settings.AutoCheckUpdates;
            RemoteManifestUrl = settings.RemoteManifestUrl ?? string.Empty;

            StatusMessage = "设置已加载";
        }
        catch (Exception ex)
        {
            StatusMessage = $"加载设置失败: {ex.Message}";
        }
    }

    private async Task SaveSettingsAsync()
    {
        try
        {
            var settings = new AppSettings
            {
                ForceOfflineMode = ForceOfflineMode,
                DownloadDirectory = DownloadDirectory,
                MaxConcurrentDownloads = MaxConcurrentDownloads,
                AutoCheckUpdates = AutoCheckUpdates,
                RemoteManifestUrl = string.IsNullOrWhiteSpace(RemoteManifestUrl) ? null : RemoteManifestUrl
            };

            await _settingsService.SaveSettingsAsync(settings);
            StatusMessage = "设置已保存";
        }
        catch (Exception ex)
        {
            StatusMessage = $"保存设置失败: {ex.Message}";
        }
    }

    private void BrowseFolder()
    {
        var dialog = new Microsoft.Win32.SaveFileDialog
        {
            Title = "选择下载目录",
            FileName = "选择文件夹",
            Filter = "文件夹|*.folder"
        };

        if (dialog.ShowDialog() == true)
        {
            DownloadDirectory = System.IO.Path.GetDirectoryName(dialog.FileName) ?? DownloadDirectory;
        }
    }
}
