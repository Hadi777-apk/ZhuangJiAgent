namespace DevEnvInit.App.ViewModels;

public abstract class StepViewModel : ObservableObject
{
    protected StepViewModel(string title, string description)
    {
        Title = title;
        Description = description;
    }

    public string Title { get; }

    public string Description { get; }
}
