using System.Collections.ObjectModel;
using System.Windows.Input;
using DevEnvInit.Core.Services;

namespace DevEnvInit.App.ViewModels;

public sealed class SoftwareSelectionViewModel : StepViewModel
{
    private readonly IManifestService _manifestService;
    private string _summary = "尚未加载软件清单。";
    private bool _isBusy;

    public SoftwareSelectionViewModel(IManifestService manifestService)
        : base("软件清单", "根据检测结果推荐安装项，并允许手动调整选择。")
    {
        _manifestService = manifestService;
        LoadPackagesCommand = new RelayCommand(async _ => await LoadPackagesAsync(), _ => !IsBusy);
    }

    public ObservableCollection<SoftwarePackageViewModel> Packages { get; } = new();

    public ICommand LoadPackagesCommand { get; }

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
            if (SetProperty(ref _isBusy, value) && LoadPackagesCommand is RelayCommand command)
            {
                command.RaiseCanExecuteChanged();
            }
        }
    }

    public async Task LoadPackagesAsync()
    {
        IsBusy = true;
        Summary = "正在读取 config.json...";
        Packages.Clear();

        try
        {
            var configuration = await _manifestService.LoadAppConfigurationAsync();
            foreach (var package in configuration.Apps.Where(app => app.Enabled))
            {
                Packages.Add(new SoftwarePackageViewModel(package));
            }

            var selectableCount = Packages.Count(package => package.IsEnabled);
            var selectedCount = Packages.Count(package => package.IsSelected);
            Summary = $"已加载 {Packages.Count} 个启用软件，{selectableCount} 个可自动选择，默认选中 {selectedCount} 个。";
        }
        catch (Exception error)
        {
            Summary = $"软件清单加载失败：{error.Message}";
        }
        finally
        {
            IsBusy = false;
        }
    }
}
