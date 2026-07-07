using System.Windows;
using DevEnvInit.App.ViewModels;

namespace DevEnvInit.App;

public partial class MainWindow : Window
{
    public MainWindow(MainWindowViewModel viewModel)
    {
        InitializeComponent();
        DataContext = viewModel;
    }
}
