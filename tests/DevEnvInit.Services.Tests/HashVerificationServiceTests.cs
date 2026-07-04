namespace DevEnvInit.Services.Tests;

public sealed class HashVerificationServiceTests
{
    [Fact]
    public async Task VerifyAsync_returns_sha256_for_existing_file()
    {
        var tempFile = Path.GetTempFileName();
        await File.WriteAllTextAsync(tempFile, "abc");
        var service = new HashVerificationService();

        try
        {
            var result = await service.VerifyAsync(TestPackages.Create(), tempFile);

            Assert.True(result.IsValid);
            Assert.Equal("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", result.ActualSha256);
        }
        finally
        {
            File.Delete(tempFile);
        }
    }

    [Fact]
    public async Task VerifyAsync_returns_failure_for_missing_file()
    {
        var service = new HashVerificationService();

        var result = await service.VerifyAsync(TestPackages.Create(), Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString("N")));

        Assert.False(result.IsValid);
        Assert.Null(result.ActualSha256);
    }
}
