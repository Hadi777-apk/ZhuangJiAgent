using DevEnvInit.Core.Models;
using DevEnvInit.Core.Services;

namespace DevEnvInit.Services;

public sealed class AllowlistService : IAllowlistService
{
    public bool IsUrlAllowed(string url, AllowlistConfiguration allowlist)
    {
        if (!Uri.TryCreate(url, UriKind.Absolute, out var uri) || uri.Scheme != Uri.UriSchemeHttps)
        {
            return false;
        }

        return allowlist.AllowedDomains.Any(domain => IsDomainAllowed(uri.Host, domain));
    }

    private static bool IsDomainAllowed(string host, string allowedDomain)
    {
        return host.Equals(allowedDomain, StringComparison.OrdinalIgnoreCase) ||
            host.EndsWith($".{allowedDomain}", StringComparison.OrdinalIgnoreCase);
    }
}
