using DevEnvInit.Core.Models;

namespace DevEnvInit.Core.Services;

public interface IAllowlistService
{
    bool IsUrlAllowed(string url, AllowlistConfiguration allowlist);
}
