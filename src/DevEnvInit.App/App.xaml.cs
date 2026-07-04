using System.IO;
using System.Windows;
using DevEnvInit.App.ViewModels;
using DevEnvInit.Core.Services;
using DevEnvInit.Core.State;
using DevEnvInit.Services;
using Microsoft.Extensions.DependencyInjection;

namespace DevEnvInit.App;

public partial class App : Application
{
    private ServiceProvider? _serviceProvider;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        var services = new ServiceCollection();
        ConfigureServices(services);
        _serviceProvider = services.BuildServiceProvider();

        var mainWindow = _serviceProvider.GetRequiredService<MainWindow>();
        mainWindow.Show();
    }

    protected override void OnExit(ExitEventArgs e)
    {
        _serviceProvider?.Dispose();
        base.OnExit(e);
    }

    private static void ConfigureServices(IServiceCollection services)
    {
        var repositoryRoot = ResolveRepositoryRoot();

        services.AddSingleton(InstallSessionState.Empty);
        services.AddSingleton<IManifestService>(_ => new ManifestService(repositoryRoot));
        services.AddSingleton<IAllowlistService, AllowlistService>();
        services.AddSingleton<IHashVerificationService, HashVerificationService>();
        services.AddSingleton<IDiskSpaceCalculatorService, DiskSpaceCalculatorService>();
        services.AddSingleton<IArchiveExtractionService, SevenZipExtractionService>();
        services.AddSingleton<IInstallerExecutionService, PowerShellInstallerService>();
        services.AddSingleton<IReportService, ReportService>();

        services.AddSingleton<DetectionViewModel>();
        services.AddSingleton<SoftwareSelectionViewModel>();
        services.AddSingleton<PathConfigViewModel>();
        services.AddSingleton<InstallProgressViewModel>();
        services.AddSingleton<ReportViewModel>();
        services.AddSingleton<MainWindowViewModel>();
        services.AddSingleton<MainWindow>();
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
}
