namespace DevEnvInit.App.ViewModels;

public sealed class SoftwareSelectionViewModel : StepViewModel
{
    public SoftwareSelectionViewModel()
        : base("软件清单", "根据检测结果推荐安装项，并允许手动调整选择。")
    {
    }
}
