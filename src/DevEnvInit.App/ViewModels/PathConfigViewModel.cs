namespace DevEnvInit.App.ViewModels;

public sealed class PathConfigViewModel : StepViewModel
{
    public PathConfigViewModel()
        : base("路径配置", "确认安装根目录、下载缓存目录和临时解压目录。")
    {
    }
}
