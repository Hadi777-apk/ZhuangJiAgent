using System.Diagnostics;
using System.Text;
using DevEnvInit.Core.Models;
using DevEnvInit.Core.Services;

namespace DevEnvInit.Services;

public sealed class PowerShellInstallerService : IInstallerExecutionService
{
    public async Task<InstallResult> InstallAsync(
        SoftwarePackage package,
        string installerPath,
        string? installDirectory,
        IProgress<InstallProgress> progress,
        CancellationToken cancellationToken = default)
    {
        if (!File.Exists(installerPath))
        {
            progress.Report(new InstallProgress(package.Name, InstallStatus.Failed, 0, "Installer file not found."));
            return CreateResult(package.Name, InstallStatus.Failed, "Installer file not found at path: " + installerPath, null);
        }

        progress.Report(new InstallProgress(package.Name, InstallStatus.Installing, 0, "Preparing..."));

        var installArgs = BuildInstallArgs(package, installerPath, installDirectory);
        var logPath = Path.Combine(Path.GetTempPath(), "DevEnvInit", $"{SanitizeFileName(package.Name)}-install.log");
        Directory.CreateDirectory(Path.GetDirectoryName(logPath)!);

        progress.Report(new InstallProgress(package.Name, InstallStatus.Installing, 10, "Starting installer process..."));

        try
        {
            var startInfo = new ProcessStartInfo
            {
                FileName = installArgs.FileName,
                Arguments = installArgs.Arguments,
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                CreateNoWindow = true,
                WorkingDirectory = Path.GetDirectoryName(installerPath) ?? string.Empty,
            };

            using var process = new Process { StartInfo = startInfo };
            var outputBuilder = new StringBuilder();
            var errorBuilder = new StringBuilder();

            process.Start();

            var outputTask = ConsumeReaderAsync(process.StandardOutput, outputBuilder, cancellationToken);
            var errorTask = ConsumeReaderAsync(process.StandardError, errorBuilder, cancellationToken);

            // Wait with periodic progress updates
            while (!process.HasExited)
            {
                cancellationToken.ThrowIfCancellationRequested();
                progress.Report(new InstallProgress(package.Name, InstallStatus.Installing, 30, "Installing..."));
                await Task.Delay(1000, cancellationToken);
            }

            await Task.WhenAll(outputTask, errorTask).WaitAsync(cancellationToken);
            process.WaitForExit();

            var exitCode = process.ExitCode;
            var logContent = $"=== STDOUT ==={Environment.NewLine}{outputBuilder}{Environment.NewLine}=== STDERR ==={Environment.NewLine}{errorBuilder}";
            await File.WriteAllTextAsync(logPath, logContent, cancellationToken);

            if (exitCode == 0)
            {
                progress.Report(new InstallProgress(package.Name, InstallStatus.Succeeded, 100, "Installation completed."));

                if (package.RefreshPathAfterInstall)
                {
                    progress.Report(new InstallProgress(package.Name, InstallStatus.Installing, 90, "Refreshing system PATH..."));
                }

                return CreateResult(package.Name, InstallStatus.Succeeded, "Installation completed successfully (exit code 0).", logPath);
            }

            var errorMsg = $"Installer exited with code {exitCode}. Check log for details.";
            progress.Report(new InstallProgress(package.Name, InstallStatus.Failed, 0, errorMsg));
            return CreateResult(package.Name, InstallStatus.Failed, errorMsg, logPath);
        }
        catch (OperationCanceledException)
        {
            progress.Report(new InstallProgress(package.Name, InstallStatus.Canceled, 0, "Installation was canceled."));
            return CreateResult(package.Name, InstallStatus.Canceled, "Installation was canceled by the user.", null);
        }
        catch (Exception ex)
        {
            var errorMsg = $"Failed to start installer: {ex.Message}";
            progress.Report(new InstallProgress(package.Name, InstallStatus.Failed, 0, errorMsg));
            return CreateResult(package.Name, InstallStatus.Failed, errorMsg, null);
        }
    }

    private static (string FileName, string Arguments) BuildInstallArgs(
        SoftwarePackage package, string installerPath, string? installDirectory)
    {
        var extension = Path.GetExtension(installerPath).ToLowerInvariant();

        if (extension == ".msi")
        {
            var args = new StringBuilder();
            args.Append($"/i \"{installerPath}\" /quiet /norestart");

            foreach (var silentArg in package.SilentArgs)
            {
                args.Append(' ').Append(silentArg);
            }

            if (!string.IsNullOrWhiteSpace(installDirectory) && package.SupportCustomInstallDir)
            {
                args.Append($" TARGETDIR=\"{installDirectory}\"");
            }

            return ("msiexec.exe", args.ToString());
        }

        // Default: .exe or other — assume silent executable
        var exeArgs = new StringBuilder();
        if (package.SilentArgs.Count > 0)
        {
            exeArgs.Append(string.Join(" ", package.SilentArgs));
        }
        else
        {
            // Common silent fallback for NSIS/Inno Setup installers
            exeArgs.Append("/S");
        }

        if (!string.IsNullOrWhiteSpace(installDirectory) && package.SupportCustomInstallDir)
        {
            if (!string.IsNullOrWhiteSpace(package.InstallDirArgsTemplate))
            {
                exeArgs.Append(' ').Append(package.InstallDirArgsTemplate.Replace("{path}", installDirectory));
            }
            else
            {
                exeArgs.Append($" /D=\"{installDirectory}\"");
            }
        }

        return (installerPath, exeArgs.ToString());
    }

    private static async Task ConsumeReaderAsync(
        StreamReader reader, StringBuilder builder, CancellationToken cancellationToken)
    {
        var buffer = new char[1024];
        while (true)
        {
            var charsRead = await reader.ReadAsync(buffer, 0, buffer.Length).WaitAsync(cancellationToken);
            if (charsRead == 0) break;
            builder.Append(buffer, 0, charsRead);
        }
    }

    private static InstallResult CreateResult(string name, InstallStatus status, string message, string? logPath) =>
        new(name, status, message, logPath);

    private static string SanitizeFileName(string name)
    {
        var invalid = Path.GetInvalidFileNameChars();
        return string.Join("_", name.Where(c => !invalid.Contains(c)));
    }
}
