using System.Text;
using DevEnvInit.Core.Models;
using DevEnvInit.Core.Services;

namespace DevEnvInit.Services;

public sealed class ReportService : IReportService
{
    public async Task<string> GenerateInstallReportAsync(
        IReadOnlyList<InstallResult> results,
        string outputDirectory,
        CancellationToken cancellationToken = default)
    {
        Directory.CreateDirectory(outputDirectory);
        var reportPath = Path.Combine(outputDirectory, $"install-report-{DateTimeOffset.Now:yyyyMMdd-HHmmss}.md");
        var content = BuildReport(results);
        await File.WriteAllTextAsync(reportPath, content, Encoding.UTF8, cancellationToken);
        return reportPath;
    }

    private static string BuildReport(IReadOnlyList<InstallResult> results)
    {
        var builder = new StringBuilder();
        builder.AppendLine("# Install Report");
        builder.AppendLine();
        builder.AppendLine("| Package | Status | Message | Log |");
        builder.AppendLine("|---|---|---|---|");

        foreach (var result in results)
        {
            builder.AppendLine($"| {Escape(result.PackageName)} | {result.Status} | {Escape(result.Message)} | {Escape(result.LogPath ?? string.Empty)} |");
        }

        return builder.ToString();
    }

    private static string Escape(string value) =>
        value.Replace("|", "\\|", StringComparison.Ordinal);
}
