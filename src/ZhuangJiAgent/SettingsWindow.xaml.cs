using System.Windows;
using ZhuangJiAgent.ViewModels;

namespace ZhuangJiAgent;

/// <summary>
/// 设置窗口
/// </summary>
public partial class SettingsWindow : Window
{
    private readonly SettingsViewModel _viewModel;
    private bool _initialized;

    public SettingsWindow(SettingsViewModel viewModel)
    {
        InitializeComponent();

        _viewModel = viewModel;
        DataContext = _viewModel;

        Loaded += OnLoaded;
    }

    private async void OnLoaded(object sender, RoutedEventArgs e)
    {
        // 单例窗口可能被多次 ShowDialog，ViewModel 只在首次加载时初始化一次
        if (_initialized)
            return;
        _initialized = true;
        await _viewModel.InitializeAsync();
    }
}
