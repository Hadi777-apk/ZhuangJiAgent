using System.Collections.ObjectModel;
using System.Windows.Input;
using DevEnvInit.Core.Models;
using DevEnvInit.Core.Services;
using DevEnvInit.Core.State;

namespace DevEnvInit.App.ViewModels;

public sealed class InstallProgressViewModel : StepViewModel
{
    private readonly IInstallerExecutionService _installerService;
    private readonly IArchiveExtractionService _extractionService;
    private string _summary = "尚未开始安装。请先从前面的步骤选择合适的软件和路径。";
    private bool _isBusy;
    private int _completedCount;
    private int _totalCount;

    public InstallProgressViewModel(
        IInstallerExecutionService installerService,
        IArchiveExtractionService extractionService)
        : base("执行安装", "显示整体安装进度、软件状态和终端风格日志。")
    {
        _installerService = installerService;
        _extractionService = extractionService;
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
        Items.Clear();
        LogLines.Clear();
        _completedCount = 0;
        _totalCount = 0;
        Summary = "准备 dry-run 安装流程...";

        try
        {
            var dryRunPackages = new[]
            {
                new SoftwarePackage(
                    Name: "Git (dry-run)",
                    Installer: "not-found.exe",
                    Type: "exe",
                    RequiredVersion: string.Empty,
                    TargetMajorVersion: null,
                    CheckCommands: Array.Empty<string>(),
                    RegistryNames: Array.Empty<string>(),
                    InstallPaths: Array.Empty<string>(),
                    SilentArgs: Array.Empty<string>(),
                    FallbackArgs: Array.Empty<string>(),
                    VersionCommand: string.Empty,
                    Enabled: true,
                    ForceUpgradeWhenVersionUnknown: false,
                    Installable: true,
                    SupportCustomInstallDir: false,
                    CustomInstallDir: string.Empty,
                    InstallDirArgsTemplate: string.Empty,
                    InstallLocationRisk: string.Empty,
                    InstallLocationPolicy: string.Empty,
                    InstallLocationNotes: string.Empty,
                    AppxNames: Array.Empty<string>(),
                    ProcessNames: Array.Empty<string>(),
                    ShortcutNames: Array.Empty<string>(),
                    RegistryExcludeNames: Array.Empty<string>(),
                    InstallerKind: null,
                    OfflineInstallSupported: false,
                    RequiresNetwork: false,
                    RequiresStoreInstaller: false,
                    AutoInstallEnabled: false,
                    RequireManualConfirmBeforeInstall: false,
                    RefreshPathAfterInstall: false,
                    ManagedBy: null,
                    TimeoutMinutes: null),
                new SoftwarePackage(
                    Name: "Python 3.12 (dry-run)",
                    Installer: "python-3.12.exe",
                    Type: "exe",
                    RequiredVersion: string.Empty,
                    TargetMajorVersion: null,
                    CheckCommands: Array.Empty<string>(),
                    RegistryNames: Array.Empty<string>(),
                    InstallPaths: Array.Empty<string>(),
                    SilentArgs: Array.Empty<string>(),
                    FallbackArgs: Array.Empty<string>(),
                    VersionCommand: string.Empty,
                    Enabled: true,
                    ForceUpgradeWhenVersionUnknown: false,
                    Installable: true,
                    SupportCustomInstallDir: false,
                    CustomInstallDir: string.Empty,
                    InstallDirArgsTemplate: string.Empty,
                    InstallLocationRisk: string.Empty,
                    InstallLocationPolicy: string.Empty,
                    InstallLocationNotes: string.Empty,
                    AppxNames: Array.Empty<string>(),
                    ProcessNames: Array.Empty<string>(),
                    ShortcutNames: Array.Empty<string>(),
                    RegistryExcludeNames: Array.Empty<string>(),
                    InstallerKind: null,
                    OfflineInstallSupported: false,
                    RequiresNetwork: false,
                    RequiresStoreInstaller: false,
                    AutoInstallEnabled: false,
                    RequireManualConfirmBeforeInstall: false,
                    RefreshPathAfterInstall: false,
                    ManagedBy: null,
                    TimeoutMinutes: null),
            };

            _totalCount = dryRunPackages.Length;

            foreach (var package in dryRunPackages)
            {
                var item = new InstallProgressItem(package.Name);
                Items.Add(item);
                LogLines.Add($"[{DateTime.Now:HH:mm:ss}] 正在处理：{package.Name}");

                item.Status = InstallStatus.Extracting;
                LogLines.Add($"[{DateTime.Now:HH:mm:ss}] 提取临时文件...");
                await Task.Delay(300);

                item.Status = InstallStatus.Succeeded;
                item.LogMessage = "Dry-run 完成（模拟成功）。";
                LogLines.Add($"[{DateTime.Now:HH:mm:ss}] {package.Name}：Dry-run 成功（未执行真实安装）。");
                _completedCount++;
                OnPropertyChanged(nameof(ProgressPercent));
            }

            Summary = $"Dry-run 完成：{_completedCount}/{_totalCount} 个软件处理成功。";
            LogLines.Add($"[{DateTime.Now:HH:mm:ss}] ===== Dry-run 安装完成 =====");
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
