namespace DevEnvInit.Core.Models;

public sealed record AllowlistConfiguration(
    IReadOnlyList<string> AllowedDomains,
    string Notes);
