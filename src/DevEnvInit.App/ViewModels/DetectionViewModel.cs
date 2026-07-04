namespace DevEnvInit.App.ViewModels;

public sealed class DetectionViewModel : StepViewModel
{
    public DetectionViewModel()
        : base("环境检测", "检查管理员权限、系统版本、网络状态和本地安装包完整性。")
    {
    }
}
