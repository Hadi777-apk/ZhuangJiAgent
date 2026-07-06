using System.Windows;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using ZhuangJiAgent.Services;
using ZhuangJiAgent.ViewModels;

namespace ZhuangJiAgent;

/// <summary>
/// Application entry point with DI container
/// </summary>
public partial class App : Application
{
    private readonly IHost _host;

    public App()
    {
        _host = Host.CreateDefaultBuilder()
            .ConfigureServices((context, services) =>
            {
                // 配置服务注册
                ConfigureServices(services);
            })
            .Build();
    }

    private static void ConfigureServices(IServiceCollection services)
    {
        // Phase 2 - 网络和清单服务
        services.AddSingleton<INetworkDetector, NetworkDetector>();
        services.AddSingleton<IManifestService, ManifestService>();
        services.AddSingleton<ISourceResolver, SourceResolver>();

        // Phase 3 - 下载和更新服务
        services.AddSingleton<IDownloadService, DownloadService>();
        services.AddSingleton<IUpdateService, UpdateService>();

        // Phase 4 - 安装和检测服务
        services.AddSingleton<IDetectionService, DetectionService>();
        services.AddSingleton<IInstallService, InstallService>();

        // 设置服务
        services.AddSingleton<ISettingsService, SettingsService>();

        // Phase 6 - ViewModels
        services.AddSingleton<MainViewModel>();
        services.AddTransient<SettingsViewModel>();

        // 注册窗口
        services.AddSingleton<MainWindow>();
        services.AddTransient<SettingsWindow>();
    }

    protected override async void OnStartup(StartupEventArgs e)
    {
        await _host.StartAsync();

        var mainWindow = _host.Services.GetRequiredService<MainWindow>();
        mainWindow.Show();

        base.OnStartup(e);
    }

    protected override async void OnExit(ExitEventArgs e)
    {
        await _host.StopAsync();
        _host.Dispose();

        base.OnExit(e);
    }
}

