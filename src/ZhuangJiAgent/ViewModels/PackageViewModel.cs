using ZhuangJiAgent.Models;

namespace ZhuangJiAgent.ViewModels;

/// <summary>
/// 单个软件包的 ViewModel
/// </summary>
public sealed class PackageViewModel : ViewModelBase
{
    private bool _isSelected;
    private InstallStatus _installStatus;
    private string? _statusMessage;
    private double _progressPercentage;
    private bool _isProgressVisible;

    public PackageViewModel(SoftwarePackage package)
    {
        Package = package;
        _isSelected = package.DefaultSelected;
        _installStatus = InstallStatus.Pending;
    }

    /// <summary>
    /// 软件包数据
    /// </summary>
    public SoftwarePackage Package { get; }

    /// <summary>
    /// 是否选中
    /// </summary>
    public bool IsSelected
    {
        get => _isSelected;
        set => SetProperty(ref _isSelected, value);
    }

    /// <summary>
    /// 安装状态
    /// </summary>
    public InstallStatus InstallStatus
    {
        get => _installStatus;
        set => SetProperty(ref _installStatus, value);
    }

    /// <summary>
    /// 状态消息
    /// </summary>
    public string? StatusMessage
    {
        get => _statusMessage;
        set => SetProperty(ref _statusMessage, value);
    }

    /// <summary>
    /// 进度百分比（0-100）
    /// </summary>
    public double ProgressPercentage
    {
        get => _progressPercentage;
        set => SetProperty(ref _progressPercentage, value);
    }

    /// <summary>
    /// 进度条是否可见
    /// </summary>
    public bool IsProgressVisible
    {
        get => _isProgressVisible;
        set => SetProperty(ref _isProgressVisible, value);
    }

    /// <summary>
    /// 显示名称
    /// </summary>
    public string DisplayName => Package.Name;

    /// <summary>
    /// 版本
    /// </summary>
    public string Version => Package.Version;

    /// <summary>
    /// 分类
    /// </summary>
    public string Category => Package.Category;

    /// <summary>
    /// 发布者
    /// </summary>
    public string Publisher => Package.Publisher;

    /// <summary>
    /// 描述
    /// </summary>
    public string? Description => Package.Description;

    /// <summary>
    /// 是否有更新
    /// </summary>
    public bool HasUpdate { get; set; }

    /// <summary>
    /// 最新版本（如果有更新）
    /// </summary>
    public string? LatestVersion { get; set; }
}
