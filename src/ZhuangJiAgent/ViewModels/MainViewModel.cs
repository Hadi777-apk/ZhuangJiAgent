using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Windows.Data;
using System.Windows.Input;
using ZhuangJiAgent.Models;
using ZhuangJiAgent.Services;

namespace ZhuangJiAgent.ViewModels;

/// <summary>
/// 主窗口 ViewModel
/// </summary>
public sealed class MainViewModel : ViewModelBase
{
    private readonly ISourceResolver _sourceResolver;
    private readonly IUpdateService _updateService;
    private readonly IInstallService _installService;
    private readonly IDownloadService _downloadService;
    private readonly Func<SettingsWindow> _settingsWindowFactory;

    private string _statusMessage = "正在加载...";
    private bool _isLoading = true;
    private bool _hasUpdates;
    private NetworkState _networkState = NetworkState.Unknown;
    private UpdateReport? _updateReport;
    private string _selectedCategory = "全部";
    private string _searchText = string.Empty;

    public MainViewModel(
        ISourceResolver sourceResolver,
        IUpdateService updateService,
        IInstallService installService,
        IDownloadService downloadService,
        Func<SettingsWindow> settingsWindowFactory)
    {
        _sourceResolver = sourceResolver;
        _updateService = updateService;
        _installService = installService;
        _downloadService = downloadService;
        _settingsWindowFactory = settingsWindowFactory;

        Packages = new ObservableCollection<PackageViewModel>();
        Categories = new ObservableCollection<string> { "全部" };

        // 创建过滤视图
        PackagesView = CollectionViewSource.GetDefaultView(Packages);
        PackagesView.Filter = FilterPackage;

        CheckUpdateCommand = new RelayCommand(async () => await CheckForUpdatesAsync());
        ApplyUpdatesCommand = new RelayCommand(async () => await ApplyUpdatesAsync(), () => HasUpdates);
        InstallSelectedCommand = new RelayCommand(async () => await InstallSelectedPackagesAsync(), () => Packages.Any(p => p.IsSelected));
        SelectAllCommand = new RelayCommand(async () => { await Task.CompletedTask; SelectAll(); });
        UnselectAllCommand = new RelayCommand(async () => { await Task.CompletedTask; UnselectAll(); });
        OpenSettingsCommand = new RelayCommand(async () => { await Task.CompletedTask; OpenSettings(); });
    }

    /// <summary>
    /// 软件包列表
    /// </summary>
    public ObservableCollection<PackageViewModel> Packages { get; }

    /// <summary>
    /// 软件包视图（支持过滤）
    /// </summary>
    public ICollectionView PackagesView { get; }

    /// <summary>
    /// 分类列表
    /// </summary>
    public ObservableCollection<string> Categories { get; }

    /// <summary>
    /// 选中的分类
    /// </summary>
    public string SelectedCategory
    {
        get => _selectedCategory;
        set
        {
            if (SetProperty(ref _selectedCategory, value))
            {
                ApplyFilter();
            }
        }
    }

    /// <summary>
    /// 搜索文本
    /// </summary>
    public string SearchText
    {
        get => _searchText;
        set
        {
            if (SetProperty(ref _searchText, value))
            {
                ApplyFilter();
            }
        }
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
    /// 是否正在加载
    /// </summary>
    public bool IsLoading
    {
        get => _isLoading;
        set => SetProperty(ref _isLoading, value);
    }

    /// <summary>
    /// 是否有可用更新
    /// </summary>
    public bool HasUpdates
    {
        get => _hasUpdates;
        set
        {
            if (SetProperty(ref _hasUpdates, value))
            {
                (ApplyUpdatesCommand as RelayCommand)?.RaiseCanExecuteChanged();
            }
        }
    }

    /// <summary>
    /// 网络状态
    /// </summary>
    public NetworkState NetworkState
    {
        get => _networkState;
        set => SetProperty(ref _networkState, value);
    }

    /// <summary>
    /// 检查更新命令
    /// </summary>
    public ICommand CheckUpdateCommand { get; }

    /// <summary>
    /// 应用更新命令
    /// </summary>
    public ICommand ApplyUpdatesCommand { get; }

    /// <summary>
    /// 安装选中软件命令
    /// </summary>
    public ICommand InstallSelectedCommand { get; }

    /// <summary>
    /// 全选命令
    /// </summary>
    public ICommand SelectAllCommand { get; }

    /// <summary>
    /// 取消全选命令
    /// </summary>
    public ICommand UnselectAllCommand { get; }

    /// <summary>
    /// 打开设置命令
    /// </summary>
    public ICommand OpenSettingsCommand { get; }

    /// <summary>
    /// 初始化加载
    /// </summary>
    public async Task InitializeAsync()
    {
        IsLoading = true;
        StatusMessage = "正在加载软件清单...";

        try
        {
            // 解析生效的清单
            var (manifest, networkState) = await _sourceResolver.ResolveManifestAsync();
            NetworkState = networkState;

            // 加载软件包
            Packages.Clear();
            Categories.Clear();
            Categories.Add("全部");

            var allCategories = new HashSet<string>();

            foreach (var package in manifest.Packages.OrderBy(p => p.Order))
            {
                Packages.Add(new PackageViewModel(package));
                allCategories.Add(package.Category);
            }

            // 添加分类
            foreach (var category in allCategories.OrderBy(c => c))
            {
                Categories.Add(category);
            }

            StatusMessage = $"已加载 {Packages.Count} 个软件包 ({(networkState == NetworkState.Online ? "在线" : "离线")}模式)";

            // 后台静默检查更新
            if (networkState == NetworkState.Online)
            {
                _ = Task.Run(async () => await CheckForUpdatesAsync());
            }
        }
        catch (Exception ex)
        {
            StatusMessage = $"加载失败: {ex.Message}";
        }
        finally
        {
            IsLoading = false;
        }
    }

    /// <summary>
    /// 检查更新
    /// </summary>
    private async Task CheckForUpdatesAsync()
    {
        try
        {
            StatusMessage = "正在检查更新...";
            _updateReport = await _updateService.CheckForUpdatesAsync();

            if (_updateReport.HasUpdates && _updateReport.Diff is not null)
            {
                HasUpdates = true;

                // 标记有更新的包
                foreach (var update in _updateReport.Diff.UpdatedPackages)
                {
                    var vm = Packages.FirstOrDefault(p => p.Package.Id == update.PackageId);
                    if (vm is not null)
                    {
                        vm.HasUpdate = true;
                        vm.LatestVersion = update.LatestVersion;
                    }
                }

                var totalSize = _updateReport.Diff.TotalDownloadSize / 1024.0 / 1024.0;
                StatusMessage = $"发现 {_updateReport.Diff.UpdatedPackages.Count} 个更新 ({totalSize:F1} MB)";
            }
            else
            {
                HasUpdates = false;
                StatusMessage = "所有软件包已是最新版本";
            }
        }
        catch (Exception ex)
        {
            StatusMessage = $"检查更新失败: {ex.Message}";
        }
    }

    /// <summary>
    /// 应用更新
    /// </summary>
    private async Task ApplyUpdatesAsync()
    {
        if (_updateReport is null)
            return;

        try
        {
            StatusMessage = "正在下载更新...";
            var success = await _updateService.ApplyUpdatesAsync(_updateReport);

            if (success)
            {
                StatusMessage = "更新完成";
                HasUpdates = false;

                // 重新加载清单
                await InitializeAsync();
            }
            else
            {
                StatusMessage = "更新失败";
            }
        }
        catch (Exception ex)
        {
            StatusMessage = $"更新失败: {ex.Message}";
        }
    }

    /// <summary>
    /// 安装选中的软件包
    /// </summary>
    private async Task InstallSelectedPackagesAsync()
    {
        var selected = Packages.Where(p => p.IsSelected).ToList();
        if (selected.Count == 0)
        {
            StatusMessage = "请先选择要安装的软件包";
            return;
        }

        IsLoading = true;

        try
        {
            StatusMessage = $"正在准备安装 {selected.Count} 个软件包...";

            // 1. 确定需要下载的包（没有本地路径或本地文件不存在）
            var packagesNeedDownload = new List<SoftwarePackage>();
            var installerPaths = new Dictionary<string, string>();

            foreach (var vm in selected)
            {
                var package = vm.Package;

                // 检查是否有本地路径
                if (!string.IsNullOrWhiteSpace(package.Installer.LocalPath))
                {
                    var localPath = System.IO.Path.GetFullPath(package.Installer.LocalPath);
                    if (System.IO.File.Exists(localPath))
                    {
                        installerPaths[package.Id] = localPath;
                        continue;
                    }
                }

                // 需要下载
                if (!string.IsNullOrWhiteSpace(package.Installer.Url))
                {
                    packagesNeedDownload.Add(package);
                }
                else
                {
                    vm.InstallStatus = InstallStatus.Failed;
                    vm.StatusMessage = "无可用安装源";
                }
            }

            // 2. 下载需要的包
            if (packagesNeedDownload.Count > 0)
            {
                StatusMessage = $"正在下载 {packagesNeedDownload.Count} 个软件包...";

                var downloadProgress = new Progress<DownloadProgress>(progress =>
                {
                    var vm = Packages.FirstOrDefault(p => p.Package.Id == progress.PackageId);
                    if (vm is not null)
                    {
                        // 更新进度条
                        vm.ProgressPercentage = progress.ProgressPercentage;
                        vm.IsProgressVisible = progress.State == DownloadState.Downloading || progress.State == DownloadState.Verifying;

                        vm.StatusMessage = progress.State switch
                        {
                            DownloadState.Downloading => $"下载中 {progress.ProgressPercentage:F1}% ({FormatSpeed(progress.BytesPerSecond)})",
                            DownloadState.Verifying => "校验中...",
                            DownloadState.Completed => "下载完成",
                            DownloadState.Failed => $"下载失败: {progress.ErrorMessage}",
                            _ => "等待中"
                        };

                        // 下载完成后隐藏进度条
                        if (progress.State == DownloadState.Completed || progress.State == DownloadState.Failed)
                        {
                            vm.IsProgressVisible = false;
                        }
                    }
                });

                var downloadedPaths = await _downloadService.DownloadPackagesAsync(
                    packagesNeedDownload,
                    "downloads/cache",
                    downloadProgress);

                foreach (var (packageId, path) in downloadedPaths)
                {
                    installerPaths[packageId] = path;
                }
            }

            // 3. 按顺序安装
            StatusMessage = $"正在安装软件包...";

            var sortedSelected = selected.OrderBy(vm => vm.Package.Order).ToList();

            foreach (var vm in sortedSelected)
            {
                if (!installerPaths.TryGetValue(vm.Package.Id, out var installerPath))
                {
                    vm.InstallStatus = InstallStatus.Failed;
                    vm.StatusMessage = "未找到安装文件";
                    continue;
                }

                vm.InstallStatus = InstallStatus.Installing;
                vm.StatusMessage = "正在安装...";

                var result = await _installService.CheckAndInstallAsync(
                    vm.Package,
                    installerPath);

                vm.InstallStatus = result.Status;
                vm.StatusMessage = result.Status switch
                {
                    InstallStatus.Success => $"安装成功 ({result.ElapsedSeconds:F1}s)",
                    InstallStatus.AlreadyInstalled => "已安装",
                    InstallStatus.Failed => $"失败: {result.ErrorMessage}",
                    _ => "未知状态"
                };

                if (result.RequiresReboot)
                {
                    vm.StatusMessage += " (需要重启)";
                }
            }

            var successCount = sortedSelected.Count(vm => vm.InstallStatus == InstallStatus.Success || vm.InstallStatus == InstallStatus.AlreadyInstalled);
            var failedCount = sortedSelected.Count(vm => vm.InstallStatus == InstallStatus.Failed);

            StatusMessage = $"安装完成: 成功 {successCount} 个, 失败 {failedCount} 个";
        }
        catch (Exception ex)
        {
            StatusMessage = $"安装失败: {ex.Message}";

            foreach (var vm in selected)
            {
                if (vm.InstallStatus == InstallStatus.Installing)
                {
                    vm.InstallStatus = InstallStatus.Failed;
                    vm.StatusMessage = "安装中断";
                }
            }
        }
        finally
        {
            IsLoading = false;
        }
    }

    private static string FormatSpeed(long bytesPerSecond)
    {
        if (bytesPerSecond < 1024)
            return $"{bytesPerSecond} B/s";
        if (bytesPerSecond < 1024 * 1024)
            return $"{bytesPerSecond / 1024.0:F1} KB/s";
        return $"{bytesPerSecond / 1024.0 / 1024.0:F1} MB/s";
    }

    private void SelectAll()
    {
        foreach (var package in Packages)
        {
            package.IsSelected = true;
        }
        (InstallSelectedCommand as RelayCommand)?.RaiseCanExecuteChanged();
    }

    private void UnselectAll()
    {
        foreach (var package in Packages)
        {
            package.IsSelected = false;
        }
        (InstallSelectedCommand as RelayCommand)?.RaiseCanExecuteChanged();
    }

    private void ApplyFilter()
    {
        PackagesView.Refresh();
    }

    private bool FilterPackage(object obj)
    {
        if (obj is not PackageViewModel package)
            return false;

        // 分类过滤
        if (SelectedCategory != "全部" && package.Category != SelectedCategory)
            return false;

        // 搜索过滤
        if (!string.IsNullOrWhiteSpace(SearchText))
        {
            var searchLower = SearchText.ToLowerInvariant();
            return package.DisplayName.ToLowerInvariant().Contains(searchLower) ||
                   (package.Description?.ToLowerInvariant().Contains(searchLower) ?? false) ||
                   package.Category.ToLowerInvariant().Contains(searchLower) ||
                   package.Publisher.ToLowerInvariant().Contains(searchLower);
        }

        return true;
    }

    private void OpenSettings()
    {
        var settingsWindow = _settingsWindowFactory();
        settingsWindow.Owner = System.Windows.Application.Current.MainWindow;
        settingsWindow.ShowDialog();
    }
}

/// <summary>
/// 简单的 RelayCommand 实现
/// </summary>
public sealed class RelayCommand : ICommand
{
    private readonly Func<Task> _execute;
    private readonly Func<bool>? _canExecute;

    public RelayCommand(Func<Task> execute, Func<bool>? canExecute = null)
    {
        _execute = execute;
        _canExecute = canExecute;
    }

    public event EventHandler? CanExecuteChanged;

    public bool CanExecute(object? parameter) => _canExecute?.Invoke() ?? true;

    public async void Execute(object? parameter) => await _execute();

    public void RaiseCanExecuteChanged() => CanExecuteChanged?.Invoke(this, EventArgs.Empty);
}
