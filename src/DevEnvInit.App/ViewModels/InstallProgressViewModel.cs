using System.Collections.ObjectModel;
using System.IO;
using System.Windows.Input;
using DevEnvInit.Core.Models;
using DevEnvInit.Core.Services;
using DevEnvInit.Core.State;

namespace DevEnvInit.App.ViewModels;

public sealed class InstallProgressViewModel : StepViewModel
{
    private readonly IInstallerExecutionService _installerService;
    private readonly IManifestService _manifestService;
    private string _summary = "尚未开始安装。请先从前面的步骤选择合适的软件和路径。";
    private bool _isBusy;
    private int _completedCount;
    private int _totalCount;
    private CancellationTokenSource? _cts;

    public InstallProgressViewModel(
        IInstallerExecutionService installerService,
        IManifestService manifestService)
        : base("执行安装", "显示整体安装进度、软件状态和终端风格日志。")
    {
        _installerService = installerService;
        _manifestService = manifestService;
        StartInstallCommand = new RelayCommand(async _ => await StartInstallAsync(), _ => !IsBusy);
    }

    public ObservableCollection<InstallProgressItem> Items { get; } = new();

    public ObservableCollection<string> LogLines { get; } = new();

    public ICommand StartInstallCommand { get; }

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
            if (SetProperty(ref _isBusy, value) && StartInstallCommand is RelayCommand command)
            {
                command.RaiseCanExecuteChanged();
            }
        }
    }

    public double ProgressPercent => _totalCount > 0 ? (double)_completedCount / _totalCount * 100.0 : 0;

    public async Task StartInstallAsync()
    {
        IsBusy = true;
        _cts?.Dispose();
        _cts = new CancellationTokenSource();
        Items.Clear();
        LogLines.Clear();
        _completedCount = 0;
        _totalCount = 0;
        Summary = "正在加载配置并准备安装...";

        try
        {
            var configuration = await _manifestService.LoadAppConfigurationAsync();
            var repositoryRoot = ResolveRepositoryRoot();
            var installersDir = Path.Combine(repositoryRoot, "installers");

            var packagesToInstall = configuration.Apps
                .Where(app => app.Enabled && app.Installable && !app.RequireManualConfirmBeforeInstall)
                .ToArray();

            _totalCount = packagesToInstall.Length;

            if (_totalCount == 0)
            {
                Summary = "没有可自动安装的软件。请先在软件清单页选择可安装的软件。";
                return;
            }

            Summary = $"准备安装 {_totalCount} 个软件...";
            LogLines.Add($"[{DateTime.Now:HH:mm:ss}] ===== 开始安装 =====");
            LogLines.Add($"[{DateTime.Now:HH:mm:ss}] 共 {_totalCount} 个可自动安装的软件。");

            foreach (var package in packagesToInstall)
            {
                _cts.Token.ThrowIfCancellationRequested();

                var item = new InstallProgressItem(package.Name);
                Items.Add(item);
                LogLines.Add($"[{DateTime.Now:HH:mm:ss}] 开始处理：{package.Name}");

                if (string.IsNullOrWhiteSpace(package.Installer))
                {
                    LogLines.Add($"[{DateTime.Now:HH:mm:ss}] {package.Name}：无安装包（ManagedBy={package.ManagedBy ?? "none"}），标记为跳过。");
                    item.Status = InstallStatus.Skipped;
                    item.LogMessage = "无安装包";
                    _completedCount++;
                    OnPropertyChanged(nameof(ProgressPercent));
                    continue;
                }

                var installerPath = GetSafeInstallerPath(installersDir, package.Installer);
                if (installerPath is null || !File.Exists(installerPath))
                {
                    LogLines.Add($"[{DateTime.Now:HH:mm:ss}] {package.Name}：安装包未找到（{installerPath}），标记为失败。");
                    item.Status = InstallStatus.Failed;
                    item.LogMessage = "安装包未找到";
                    _completedCount++;
                    OnPropertyChanged(nameof(ProgressPercent));
                    continue;
                }

                item.Status = InstallStatus.Installing;
                LogLines.Add($"[{DateTime.Now:HH:mm:ss}] {package.Name}：正在安装...");

                var progress = new Progress<InstallProgress>(p =>
                {
                    var logLine = $"[{DateTime.Now:HH:mm:ss}] {p.PackageName}：{p.Message}";
                    LogLines.Add(logLine);
                });

                var installDir = package.SupportCustomInstallDir && !string.IsNullOrWhiteSpace(package.CustomInstallDir)
                    ? package.CustomInstallDir
                    : null;

                try
                {
                    var result = await _installerService.InstallAsync(
                        package, installerPath, installDir, progress, _cts.Token);

                    item.Status = result.Status;
                    item.LogMessage = result.Message;

                    if (result.Status == InstallStatus.Succeeded)
                    {
                        var logNote = result.LogPath is not null ? $" 日志：{result.LogPath}" : "";
                        LogLines.Add($"[{DateTime.Now:HH:mm:ss}] ✓ {package.Name}：安装成功。{logNote}");
                    }
                    else if (result.Status == InstallStatus.Canceled)
                    {
                        LogLines.Add($"[{DateTime.Now:HH:mm:ss}] ✗ {package.Name}：已取消。");
                        Summary = $"安装已取消：{package.Name}";
                        return;
                    }
                    else
                    {
                        LogLines.Add($"[{DateTime.Now:HH:mm:ss}] ✗ {package.Name}：安装失败（{result.Message}）。日志：{result.LogPath}");
                    }
                }
                catch (OperationCanceledException)
                {
                    LogLines.Add($"[{DateTime.Now:HH:mm:ss}] ✗ {package.Name}：已取消。");
                    item.Status = InstallStatus.Canceled;
                    item.LogMessage = "已取消";
                    return;
                }
                catch (Exception error)
                {
                    LogLines.Add($"[{DateTime.Now:HH:mm:ss}] ✗ {package.Name}：异常（{error.Message}）");
                    item.Status = InstallStatus.Failed;
                    item.LogMessage = error.Message;
                }

                _completedCount++;
                OnPropertyChanged(nameof(ProgressPercent));
            }

            var succeeded = Items.Count(i => i.Status == InstallStatus.Succeeded);
            var failed = Items.Count(i => i.Status == InstallStatus.Failed);
            var skipped = Items.Count(i => i.Status == InstallStatus.Skipped);
            Summary = $"安装完成：成功 {succeeded}，失败 {failed}，跳过 {skipped}，共 {_totalCount}";
            LogLines.Add($"[{DateTime.Now:HH:mm:ss}] ===== 安装完成 =====");
        }
        catch (OperationCanceledException)
        {
            Summary = "安装已取消。";
        }
        catch (Exception error)
        {
            Summary = $"安装流程失败：{error.Message}";
            LogLines.Add($"[{DateTime.Now:HH:mm:ss}] 错误：{error.Message}");
        }
        finally
        {
            IsBusy = false;
        }
    }

    private static string ResolveRepositoryRoot()
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null && !File.Exists(Path.Combine(directory.FullName, "config.json")))
        {
            directory = directory.Parent;
        }

        return directory?.FullName ?? AppContext.BaseDirectory;
    }

    private static string? GetSafeInstallerPath(string installersDir, string installer)
    {
        if (string.IsNullOrWhiteSpace(installer) || Path.IsPathFullyQualified(installer))
        {
            return null;
        }

        var root = Path.GetFullPath(installersDir);
        var candidate = Path.GetFullPath(Path.Combine(root, installer));
        var requiredPrefix = root.EndsWith(Path.DirectorySeparatorChar)
            ? root
            : root + Path.DirectorySeparatorChar;

        return candidate.StartsWith(requiredPrefix, StringComparison.OrdinalIgnoreCase)
            ? candidate
            : null;
    }
}

public sealed class InstallProgressItem : ObservableObject
{
    private InstallStatus _status;
    private string _logMessage = string.Empty;

    public InstallProgressItem(string packageName)
    {
        PackageName = packageName;
    }

    public string PackageName { get; }

    public InstallStatus Status
    {
        get => _status;
        set => SetProperty(ref _status, value);
    }

    public string LogMessage
    {
        get => _logMessage;
        set => SetProperty(ref _logMessage, value);
    }
}
