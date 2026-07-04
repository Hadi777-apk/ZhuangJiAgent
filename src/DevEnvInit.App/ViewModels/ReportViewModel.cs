using System.Collections.ObjectModel;
using System.IO;
using System.Windows.Input;
using DevEnvInit.Core.Models;
using DevEnvInit.Core.Services;

namespace DevEnvInit.App.ViewModels;

public sealed class ReportViewModel : StepViewModel
{
    private readonly IReportService _reportService;
    private string _summary = "尚未生成报告。请先完成安装流程。";
    private string _reportContent = string.Empty;
    private bool _isBusy;

    public ReportViewModel(IReportService reportService)
        : base("完成报告", "汇总成功、跳过、失败项，并提供日志和后续操作入口。")
    {
        _reportService = reportService;
        GenerateReportCommand = new RelayCommand(async _ => await GenerateReportAsync(), _ => !IsBusy);
    }

    public ObservableCollection<ReportItem> ReportItems { get; } = new();

    public ICommand GenerateReportCommand { get; }

    public string Summary
    {
        get => _summary;
        private set => SetProperty(ref _summary, value);
    }

    public string ReportContent
    {
        get => _reportContent;
        private set => SetProperty(ref _reportContent, value);
    }

    public bool IsBusy
    {
        get => _isBusy;
        private set
        {
            if (SetProperty(ref _isBusy, value) && GenerateReportCommand is RelayCommand command)
            {
                command.RaiseCanExecuteChanged();
            }
        }
    }

    public async Task GenerateReportAsync()
    {
        IsBusy = true;
        Summary = "正在生成安装报告...";
        ReportItems.Clear();
        ReportContent = string.Empty;

        try
        {
            var results = CreateDryRunResults();
            var outputDirectory = Path.Combine(Path.GetTempPath(), "DevEnvInit-Reports");
            var reportPath = await _reportService.GenerateInstallReportAsync(results, outputDirectory);

            ReportContent = await File.ReadAllTextAsync(reportPath);
            Summary = $"报告已生成：{reportPath}";
        }
        catch (Exception error)
        {
            Summary = $"报告生成失败：{error.Message}";
        }
        finally
        {
            IsBusy = false;
        }
    }

    private static IReadOnlyList<InstallResult> CreateDryRunResults() =>
    [
        new InstallResult("Git (dry-run)", InstallStatus.Succeeded, "Dry-run 模拟成功完成。", null),
        new InstallResult("Python 3.12 (dry-run)", InstallStatus.Succeeded, "Dry-run 模拟成功完成。", null),
        new InstallResult("Node LTS", InstallStatus.Failed, "安装器文件未找到。", "logs/node-lts.log"),
        new InstallResult("VS Code", InstallStatus.Skipped, "用户取消选择。", null),
    ];
}

public sealed class ReportItem : ObservableObject
{
    public ReportItem(
        string packageName,
        InstallStatus status,
        string message,
        string? logPath)
    {
        PackageName = packageName;
        Status = status;
        Message = message;
        LogPath = logPath;
    }

    public string PackageName { get; }
    public InstallStatus Status { get; }
    public string Message { get; }
    public string? LogPath { get; }
}
