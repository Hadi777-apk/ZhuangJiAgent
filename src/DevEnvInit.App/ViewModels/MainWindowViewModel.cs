using System.Collections.ObjectModel;
using System.Windows.Input;
using DevEnvInit.Core.State;

namespace DevEnvInit.App.ViewModels;

public sealed class MainWindowViewModel : ObservableObject
{
    private StepViewModel _currentStep;
    private readonly InstallSessionState _sessionState;

    public MainWindowViewModel(
        DetectionViewModel detection,
        SoftwareSelectionViewModel softwareSelection,
        PathConfigViewModel pathConfig,
        InstallProgressViewModel installProgress,
        ReportViewModel report,
        InstallSessionState? sessionState = null)
    {
        _sessionState = sessionState ?? InstallSessionState.Empty;
        Steps = new ObservableCollection<StepViewModel>
        {
            detection,
            softwareSelection,
            pathConfig,
            installProgress,
            report
        };
        _currentStep = detection;
        NavigateCommand = new RelayCommand(step => CurrentStep = (StepViewModel)step!, step => step is StepViewModel);
    }

    public ObservableCollection<StepViewModel> Steps { get; }

    public StepViewModel CurrentStep
    {
        get => _currentStep;
        private set
        {
            if (SetProperty(ref _currentStep, value))
            {
                OnPropertyChanged(nameof(StatusText));
            }
        }
    }

    public ICommand NavigateCommand { get; }

    public string StatusText => $"当前步骤：{CurrentStep.Title} · 管理员权限将在后续检测页读取";
}
