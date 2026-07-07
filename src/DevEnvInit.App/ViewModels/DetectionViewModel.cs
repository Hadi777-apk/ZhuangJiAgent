using System.Collections.ObjectModel;
using System.Windows.Input;
using DevEnvInit.Core.Models;
using DevEnvInit.Core.Services;

namespace DevEnvInit.App.ViewModels;

public sealed class DetectionViewModel : StepViewModel
{
    private readonly IManifestService _manifestService;
    private readonly IEnvironmentDetectionService _environmentDetectionService;
    private string _summary = "尚未开始检测。";
    private bool _isBusy;

    public DetectionViewModel(
        IManifestService manifestService,
        IEnvironmentDetectionService environmentDetectionService)
        : base("环境检测", "检查管理员权限、系统版本、网络状态和本地安装包完整性。")
    {
        _manifestService = manifestService;
        _environmentDetectionService = environmentDetectionService;
        RunDetectionCommand = new RelayCommand(async _ => await RunDetectionAsync(), _ => !IsBusy);
    }

    public ObservableCollection<DetectionResult> Results { get; } = new();

    public ICommand RunDetectionCommand { get; }

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
            if (SetProperty(ref _isBusy, value) && RunDetectionCommand is RelayCommand command)
            {
                command.RaiseCanExecuteChanged();
            }
        }
    }

    public async Task RunDetectionAsync()
    {
        IsBusy = true;
        Summary = "正在读取配置并执行只读检测...";
        Results.Clear();

        try
        {
            var configuration = await _manifestService.LoadAppConfigurationAsync();
            var snapshot = await _environmentDetectionService.DetectAsync(configuration);
            foreach (var result in snapshot.DetectionResults)
            {
                Results.Add(result);
            }

            Summary = $"管理员：{FormatBool(snapshot.IsAdministrator)} · 网络：{FormatBool(snapshot.IsNetworkAvailable)} · 系统：{snapshot.WindowsVersion} · 架构：{snapshot.Architecture}";
        }
        catch (Exception error)
        {
            Summary = $"检测失败：{error.Message}";
        }
        finally
        {
            IsBusy = false;
        }
    }

    private static string FormatBool(bool value) => value ? "是" : "否";
}
