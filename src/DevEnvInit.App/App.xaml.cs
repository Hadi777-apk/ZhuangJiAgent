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
        // 全局异常捕获 —— 防止闪退，记录崩溃日志
        AppDomain.CurrentDomain.UnhandledException += (_, args) =>
        {
            var ex = args.ExceptionObject as Exception;
            var msg = $"发生严重错误：{ex?.Message}\n{ex?.StackTrace}";
            File.AppendAllText("crash.log", $"[{DateTime.Now:yyyy-MM-dd HH:mm:ss}] {msg}\n");
            MessageBox.Show($"发生严重错误：{ex?.Message}\n\n详情已写入 crash.log", "错误",
                MessageBoxButton.OK, MessageBoxImage.Error);
        };

        DispatcherUnhandledException += (_, args) =>
        {
            var ex = args.Exception;
            var msg = $"UI 线程异常：{ex.Message}\n{ex.StackTrace}";
            File.AppendAllText("crash.log", $"[{DateTime.Now:yyyy-MM-dd HH:mm:ss}] {msg}\n");
            args.Handled = true;
            MessageBox.Show($"UI 线程异常：{ex.Message}\n\n详情已写入 crash.log", "错误",
                MessageBoxButton.OK, MessageBoxImage.Error);
        };

        TaskScheduler.UnobservedTaskException += (_, args) =>
        {
            var ex = args.Exception?.InnerException ?? args.Exception;
            var msg = $"异步任务异常：{ex?.Message}\n{ex?.StackTrace}";
            File.AppendAllText("crash.log", $"[{DateTime.Now:yyyy-MM-dd HH:mm:ss}] {msg}\n");
            args.SetObserved();
        };

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
        services.AddSingleton<IEnvironmentDetectionService>(_ => new WindowsEnvironmentDetectionService(repositoryRoot));
        services.AddSingleton<IAllowlistService, AllowlistService>();
        services.AddSingleton<IHashVerificationService, HashVerificationService>();
        services.AddSingleton<IDiskSpaceCalculatorService, DiskSpaceCalculatorService>();
        services.AddSingleton<IInstallerExecutionService, PowerShellInstallerService>();
        services.AddSingleton<IArchiveExtractionService, SevenZipExtractionService>();
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
