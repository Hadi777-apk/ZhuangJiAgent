using DevEnvInit.Core.Models;

namespace DevEnvInit.Services.Tests;

public sealed class AllowlistServiceTests
{
    [Fact]
    public void IsUrlAllowed_accepts_exact_and_subdomain_matches()
    {
        var service = new AllowlistService();
        var allowlist = new AllowlistConfiguration(["github.com"], string.Empty);

        Assert.True(service.IsUrlAllowed("https://github.com/example/repo", allowlist));
        Assert.True(service.IsUrlAllowed("https://objects.github.com/file", allowlist));
    }

    [Fact]
    public void IsUrlAllowed_rejects_suffix_spoofing_and_invalid_urls()
    {
        var service = new AllowlistService();
        var allowlist = new AllowlistConfiguration(["github.com"], string.Empty);

        Assert.False(service.IsUrlAllowed("https://github.com.evil.example/file", allowlist));
        Assert.False(service.IsUrlAllowed("ftp://github.com/file", allowlist));
        Assert.False(service.IsUrlAllowed("not a url", allowlist));
    }
}
