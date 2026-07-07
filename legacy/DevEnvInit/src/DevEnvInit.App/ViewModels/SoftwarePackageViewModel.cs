using DevEnvInit.Core.Models;

namespace DevEnvInit.App.ViewModels;

public sealed class SoftwarePackageViewModel : ObservableObject
{
    private bool _isSelected;

    public SoftwarePackageViewModel(SoftwarePackage package)
    {
        Package = package;
        _isSelected = package.Enabled && package.Installable && !package.RequireManualConfirmBeforeInstall;
    }

    public SoftwarePackage Package { get; }

    public string Name => Package.Name;

    public string Installer => string.IsNullOrWhiteSpace(Package.Installer) ? "无独立安装包" : Package.Installer;

    public string RequiredVersion => string.IsNullOrWhiteSpace(Package.RequiredVersion) ? "未指定" : Package.RequiredVersion;

    public string PolicyText => Package.InstallLocationPolicy;

    public bool IsEnabled => Package.Enabled && Package.Installable && !Package.RequireManualConfirmBeforeInstall;

    public bool IsSelected
    {
        get => _isSelected;
        set => SetProperty(ref _isSelected, value);
    }
}
