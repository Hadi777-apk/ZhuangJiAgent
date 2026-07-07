#requires -Version 5.1

$ErrorActionPreference = "Stop"

try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
} catch {
    # 某些宿主不允许修改控制台编码，忽略即可。
}

$Script:BaseDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Script:InstallersDir = Join-Path $Script:BaseDir "installers"
$Script:ReportsDir = Join-Path $Script:BaseDir "reports"
$Script:LogsDir = Join-Path $Script:BaseDir "logs"
$Script:CacheDir = Join-Path $Script:BaseDir "cache"
$Script:UpdateReportsDir = Join-Path $Script:ReportsDir "update"
$Script:UpdateLogsDir = Join-Path $Script:LogsDir "update"
$Script:SourcesDir = Join-Path $Script:BaseDir "sources"
$Script:PoliciesDir = Join-Path $Script:BaseDir "policies"
$Script:DownloadsDir = Join-Path $Script:BaseDir "downloads"
$Script:DownloadsLatestDir = Join-Path $Script:DownloadsDir "latest"
$Script:DownloadsArchiveDir = Join-Path $Script:DownloadsDir "archive"
$Script:BackupsDir = Join-Path $Script:BaseDir "backups"
$Script:ConfigBackupsDir = Join-Path $Script:BackupsDir "configs"
$Script:InstallerBackupsDir = Join-Path $Script:BackupsDir "installers"
$Script:RunStamp = Get-Date -Format "yyyyMMdd_HHmmss"
$Script:RunTime = Get-Date
$Script:LogPath = Join-Path $Script:LogsDir ("install_{0}.log" -f $Script:RunStamp)
$Script:ReportPath = Join-Path $Script:ReportsDir ("report_{0}.md" -f $Script:RunStamp)
$Script:ConfigPath = Join-Path $Script:BaseDir "config.json"
$Script:UpdateConfigPath = Join-Path $Script:BaseDir "update-config.json"
$Script:AllowlistPath = Join-Path $Script:SourcesDir "allowlist.json"
$Script:UpdateLogPath = $null
$Script:UpdateReportPath = $null
$Script:DownloadLogPath = $null
$Script:DownloadReportPath = $null
$Script:ConfigBackupLogPath = $null
$Script:ConfigBackupReportPath = $null
$Script:ConfigRestoreLogPath = $null
$Script:ConfigRestoreReportPath = $null
$Script:SafeUpgradeLogPath = $null
$Script:SafeUpgradeReportPath = $null
$Script:InstallLocationPreviewLogPath = $null
$Script:InstallLocationPreviewReportPath = $null
$Script:InstallCommandPreviewLogPath = $null
$Script:InstallCommandPreviewReportPath = $null
$Script:Config = $null
$Script:LastResults = @()
$Script:LastOperation = "未执行"
$Script:LastReportPath = $Script:ReportPath

foreach ($dir in @($Script:InstallersDir, $Script:ReportsDir, $Script:LogsDir, $Script:CacheDir, $Script:UpdateReportsDir, $Script:UpdateLogsDir, $Script:SourcesDir, $Script:PoliciesDir, $Script:DownloadsDir, $Script:DownloadsLatestDir, $Script:DownloadsArchiveDir, $Script:BackupsDir, $Script:ConfigBackupsDir, $Script:InstallerBackupsDir)) {
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

function Write-Log {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS", "DEBUG")][string]$Level = "INFO",
        [switch]$NoConsole
    )

    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[{0}] [{1}] {2}" -f $time, $Level, $Message

    try {
        Add-Content -LiteralPath $Script:LogPath -Value $line -Encoding UTF8
    } catch {
        Write-Host "[日志错误] 无法写入日志：$($_.Exception.Message)" -ForegroundColor Red
    }

    if (-not $NoConsole) {
        switch ($Level) {
            "WARN"    { Write-Host $Message -ForegroundColor Yellow }
            "ERROR"   { Write-Host $Message -ForegroundColor Red }
            "SUCCESS" { Write-Host $Message -ForegroundColor Green }
            "DEBUG"   { Write-Host $Message -ForegroundColor DarkGray }
            default   { Write-Host $Message }
        }
    }
}

function Get-ConfigValue {
    param(
        [object]$Object,
        [string]$Name,
        [object]$Default = $null
    )

    if ($null -eq $Object) {
        return $Default
    }

    $property = $Object.PSObject.Properties[$Name]
    if ($null -ne $property -and $null -ne $property.Value) {
        return $property.Value
    }

    return $Default
}

function ConvertTo-StringArray {
    param([object]$Value)

    if ($null -eq $Value) {
        return @()
    }

    if ($Value -is [System.Array]) {
        return @($Value | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    }

    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) {
        return @()
    }

    return @($text)
}

function Get-BoolConfig {
    param(
        [object]$Object,
        [string]$Name,
        [bool]$Default = $false
    )

    $value = Get-ConfigValue -Object $Object -Name $Name -Default $null
    if ($null -eq $value) {
        return $Default
    }

    if ($value -is [bool]) {
        return $value
    }

    $text = ([string]$value).Trim()
    if ($text -match "^(true|1|yes|是)$") {
        return $true
    }
    if ($text -match "^(false|0|no|否)$") {
        return $false
    }

    return $Default
}

function Test-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Ensure-Admin {
    if (Test-Admin) {
        return
    }

    Write-Log -Message "[权限] 当前不是管理员权限，正在请求提升权限..." -Level "WARN"
    $args = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    try {
        Start-Process -FilePath "powershell.exe" -ArgumentList $args -WorkingDirectory $Script:BaseDir -Verb RunAs | Out-Null
        exit 0
    } catch {
        Write-Log -Message "[错误] 管理员权限请求失败：$($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Load-Config {
    if (-not (Test-Path -LiteralPath $Script:ConfigPath)) {
        throw "找不到配置文件 config.json，路径：$Script:ConfigPath"
    }

    try {
        $raw = Get-Content -LiteralPath $Script:ConfigPath -Raw -Encoding UTF8
        $config = $raw | ConvertFrom-Json
    } catch {
        throw "config.json 格式错误或无法读取：$($_.Exception.Message)"
    }

    if ($null -eq $config.apps -or $config.apps.Count -eq 0) {
        throw "config.json 中没有 apps 配置项。"
    }

    $Script:Config = $config
    return $config
}

function ConvertTo-SizeText {
    param([Nullable[double]]$Bytes)

    if ($null -eq $Bytes -or $Bytes -lt 0) {
        return "未知"
    }

    if ($Bytes -ge 1TB) {
        return ("{0:N2} TB" -f ($Bytes / 1TB))
    }
    if ($Bytes -ge 1GB) {
        return ("{0:N2} GB" -f ($Bytes / 1GB))
    }
    if ($Bytes -ge 1MB) {
        return ("{0:N2} MB" -f ($Bytes / 1MB))
    }

    return ("{0:N0} B" -f $Bytes)
}

function Get-SystemInfo {
    $osName = "未知"
    $osVersion = "未知"
    $computerBrand = "未知"
    $computerModel = "未知"
    $cpuName = "未知"
    $cpuCores = "未知"
    $cpuThreads = "未知"
    $totalMemory = "未知"
    $freeMemory = "未知"
    $systemDiskFree = "未知"
    $toolDiskFree = "未知"
    $gpuNames = "未知"

    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        $osName = $os.Caption
        $osVersion = $os.Version
        $totalMemory = ConvertTo-SizeText -Bytes ([double]$os.TotalVisibleMemorySize * 1KB)
        $freeMemory = ConvertTo-SizeText -Bytes ([double]$os.FreePhysicalMemory * 1KB)
    } catch {
        try {
            $os = Get-WmiObject -Class Win32_OperatingSystem -ErrorAction Stop
            $osName = $os.Caption
            $osVersion = $os.Version
            $totalMemory = ConvertTo-SizeText -Bytes ([double]$os.TotalVisibleMemorySize * 1KB)
            $freeMemory = ConvertTo-SizeText -Bytes ([double]$os.FreePhysicalMemory * 1KB)
        } catch {
            Write-Log -Message "[警告] 无法读取 Windows 版本：$($_.Exception.Message)" -Level "WARN"
        }
    }

    try {
        $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
        $computerBrand = [string]$computerSystem.Manufacturer
        $computerModel = [string]$computerSystem.Model
    } catch {
        Write-Log -Message "[警告] 无法读取电脑品牌型号：$($_.Exception.Message)" -Level "WARN"
    }

    try {
        $cpu = Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop | Select-Object -First 1
        if ($null -ne $cpu) {
            $cpuName = [string]$cpu.Name
            $cpuCores = [string]$cpu.NumberOfCores
            $cpuThreads = [string]$cpu.NumberOfLogicalProcessors
        }
    } catch {
        Write-Log -Message "[警告] 无法读取 CPU 信息：$($_.Exception.Message)" -Level "WARN"
    }

    try {
        $systemDisk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter ("DeviceID='{0}'" -f $env:SystemDrive) -ErrorAction Stop
        if ($null -ne $systemDisk) {
            $systemDiskFree = ConvertTo-SizeText -Bytes ([double]$systemDisk.FreeSpace)
        }
    } catch {
        Write-Log -Message "[警告] 无法读取系统盘剩余空间：$($_.Exception.Message)" -Level "WARN"
    }

    try {
        $toolRoot = [System.IO.Path]::GetPathRoot($Script:BaseDir)
        $toolDriveName = $toolRoot.TrimEnd("\").TrimEnd(":")
        $toolDrive = Get-PSDrive -Name $toolDriveName -ErrorAction Stop
        $toolDiskFree = ConvertTo-SizeText -Bytes ([double]$toolDrive.Free)
    } catch {
        Write-Log -Message "[警告] 无法读取工具所在盘剩余空间：$($_.Exception.Message)" -Level "WARN"
    }

    try {
        $gpus = @(Get-CimInstance -ClassName Win32_VideoController -ErrorAction Stop | ForEach-Object { $_.Name } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        if ($gpus.Count -gt 0) {
            $gpuNames = ($gpus -join "；")
        }
    } catch {
        Write-Log -Message "[警告] 无法读取显卡信息：$($_.Exception.Message)" -Level "WARN"
    }

    return [PSCustomObject]@{
        ComputerName = $env:COMPUTERNAME
        UserName = [Environment]::UserName
        ComputerBrand = $computerBrand
        ComputerModel = $computerModel
        WindowsVersion = ("{0} ({1})" -f $osName, $osVersion)
        CpuName = $cpuName
        CpuCores = $cpuCores
        CpuThreads = $cpuThreads
        TotalMemory = $totalMemory
        FreeMemory = $freeMemory
        SystemDiskFree = $systemDiskFree
        ToolDiskFree = $toolDiskFree
        GpuNames = $gpuNames
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        IsAdmin = Test-Admin
        RunTime = $Script:RunTime
        BaseDir = $Script:BaseDir
        ScriptPath = $PSCommandPath
        LogPath = $Script:LogPath
        ReportPath = $Script:ReportPath
    }
}

function Get-VersionFromText {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $null
    }

    $match = [regex]::Match($Text, "(?<!\d)\d+(?:\.\d+){0,4}(?!\d)")
    if ($match.Success) {
        return $match.Value
    }

    return $null
}

function ConvertTo-VersionObject {
    param([string]$VersionText)

    $clean = Get-VersionFromText -Text $VersionText
    if ([string]::IsNullOrWhiteSpace($clean)) {
        return $null
    }

    $parts = @($clean -split "\." | ForEach-Object { [int]$_ })
    while ($parts.Count -lt 2) {
        $parts += 0
    }
    while ($parts.Count -lt 4) {
        $parts += 0
    }

    try {
        return [version](($parts[0..3]) -join ".")
    } catch {
        return $null
    }
}

function Invoke-CommandText {
    param(
        [Parameter(Mandatory = $true)][string]$CommandText,
        [int]$TimeoutSeconds = 30
    )

    Write-Log -Message "[命令] $CommandText" -Level "DEBUG" -NoConsole

    $job = Start-Job -ScriptBlock {
        param([string]$CommandText)

        try {
            $output = & cmd.exe /d /s /c $CommandText 2>&1
            $exitCode = $LASTEXITCODE
            [PSCustomObject]@{
                ExitCode = $exitCode
                Output = (($output | Out-String).Trim())
                TimedOut = $false
                Error = ""
            }
        } catch {
            [PSCustomObject]@{
                ExitCode = 1
                Output = ""
                TimedOut = $false
                Error = $_.Exception.Message
            }
        }
    } -ArgumentList $CommandText

    try {
        $completed = Wait-Job -Job $job -Timeout $TimeoutSeconds
        if ($null -eq $completed) {
            Stop-Job -Job $job -Force | Out-Null
            return [PSCustomObject]@{
                ExitCode = 124
                Output = ""
                TimedOut = $true
                Error = "命令执行超时（${TimeoutSeconds} 秒）"
            }
        }

        return Receive-Job -Job $job
    } finally {
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
    }
}

function Get-InstalledAppByRegistry {
    param(
        [string[]]$RegistryNames,
        [string[]]$ExcludeNames = @()
    )

    if ($null -eq $RegistryNames -or $RegistryNames.Count -eq 0) {
        return $null
    }

    $roots = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall"
    )

    $candidates = @()

    foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root)) {
            continue
        }

        try {
            $items = Get-ChildItem -LiteralPath $root -ErrorAction Stop
            foreach ($item in $items) {
                $props = Get-ItemProperty -LiteralPath $item.PSPath -ErrorAction SilentlyContinue
                $displayName = [string](Get-ConfigValue -Object $props -Name "DisplayName" -Default "")
                if ([string]::IsNullOrWhiteSpace($displayName)) {
                    continue
                }

                $excluded = $false
                foreach ($exclude in $ExcludeNames) {
                    if (-not [string]::IsNullOrWhiteSpace($exclude) -and $displayName -like ("*" + $exclude + "*")) {
                        $excluded = $true
                        break
                    }
                }
                if ($excluded) {
                    continue
                }

                foreach ($keyword in $RegistryNames) {
                    if ($displayName -like ("*" + $keyword + "*")) {
                        $displayVersion = [string](Get-ConfigValue -Object $props -Name "DisplayVersion" -Default "")
                        $installLocation = [string](Get-ConfigValue -Object $props -Name "InstallLocation" -Default "")
                        $score = 10
                        if ($displayName -eq $keyword) { $score += 100 }
                        if ($displayName -like ("*" + $keyword + "*")) { $score += 20 }
                        if (-not [string]::IsNullOrWhiteSpace($displayVersion)) { $score += 30 }
                        if (-not [string]::IsNullOrWhiteSpace($installLocation)) { $score += 10 }

                        $candidates += [PSCustomObject]@{
                            DisplayName = $displayName
                            DisplayVersion = $displayVersion
                            Publisher = [string](Get-ConfigValue -Object $props -Name "Publisher" -Default "")
                            InstallLocation = $installLocation
                            UninstallString = [string](Get-ConfigValue -Object $props -Name "UninstallString" -Default "")
                            RegistryPath = $item.PSPath
                            Score = $score
                        }
                    }
                }
            }
        } catch {
            Write-Log -Message "[警告] 读取注册表失败：$root，原因：$($_.Exception.Message)" -Level "WARN"
        }
    }

    if ($candidates.Count -gt 0) {
        return ($candidates | Sort-Object Score -Descending | Select-Object -First 1)
    }

    return $null
}

function Get-InstalledAppByAppx {
    param([string[]]$AppxNames)

    if ($null -eq $AppxNames -or $AppxNames.Count -eq 0) {
        return $null
    }

    foreach ($name in $AppxNames) {
        if ([string]::IsNullOrWhiteSpace($name)) {
            continue
        }

        try {
            $packages = @(Get-AppxPackage -Name $name -ErrorAction SilentlyContinue)
            if ($packages.Count -eq 0) {
                $packages = @(Get-AppxPackage -ErrorAction SilentlyContinue | Where-Object {
                    $_.Name -like ("*" + $name + "*") -or $_.PackageFullName -like ("*" + $name + "*")
                })
            }

            $package = $packages | Sort-Object Version -Descending | Select-Object -First 1
            if ($null -ne $package) {
                return [PSCustomObject]@{
                    Name = $package.Name
                    PackageFullName = $package.PackageFullName
                    Version = [string]$package.Version
                    InstallLocation = [string]$package.InstallLocation
                }
            }
        } catch {
            Write-Log -Message "[警告] Appx 检测失败：$name，原因：$($_.Exception.Message)" -Level "WARN"
        }
    }

    return $null
}

function Get-InstalledAppByProcess {
    param([string[]]$ProcessNames)

    if ($null -eq $ProcessNames -or $ProcessNames.Count -eq 0) {
        return $null
    }

    foreach ($processName in $ProcessNames) {
        if ([string]::IsNullOrWhiteSpace($processName)) {
            continue
        }

        try {
            $process = Get-Process -Name $processName -ErrorAction SilentlyContinue |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_.Path) } |
                Select-Object -First 1

            if ($null -ne $process) {
                return [PSCustomObject]@{
                    ProcessName = $process.ProcessName
                    Path = $process.Path
                    Version = Get-FileVersionFromPath -Path $process.Path
                }
            }
        } catch {
            Write-Log -Message "[警告] 进程检测失败：$processName，原因：$($_.Exception.Message)" -Level "WARN"
        }
    }

    return $null
}

function Get-InstalledAppByShortcut {
    param([string[]]$ShortcutNames)

    if ($null -eq $ShortcutNames -or $ShortcutNames.Count -eq 0) {
        return $null
    }

    $folders = @(
        [Environment]::GetFolderPath("Programs"),
        [Environment]::GetFolderPath("CommonPrograms"),
        [Environment]::GetFolderPath("Desktop"),
        [Environment]::GetFolderPath("CommonDesktopDirectory")
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and (Test-Path -LiteralPath $_) }

    try {
        $shell = New-Object -ComObject WScript.Shell
    } catch {
        Write-Log -Message "[警告] 无法创建快捷方式读取组件：$($_.Exception.Message)" -Level "WARN"
        return $null
    }

    foreach ($folder in $folders) {
        $links = Get-ChildItem -LiteralPath $folder -Recurse -Filter "*.lnk" -ErrorAction SilentlyContinue
        foreach ($link in $links) {
            foreach ($keyword in $ShortcutNames) {
                if ($link.BaseName -like ("*" + $keyword + "*")) {
                    try {
                        $shortcut = $shell.CreateShortcut($link.FullName)
                        $target = [Environment]::ExpandEnvironmentVariables([string]$shortcut.TargetPath)
                        if (-not [string]::IsNullOrWhiteSpace($target) -and (Test-Path -LiteralPath $target)) {
                            return [PSCustomObject]@{
                                Name = $link.BaseName
                                LinkPath = $link.FullName
                                TargetPath = $target
                                Version = Get-FileVersionFromPath -Path $target
                            }
                        }
                    } catch {
                        Write-Log -Message "[警告] 读取快捷方式失败：$($link.FullName)，原因：$($_.Exception.Message)" -Level "WARN"
                    }
                }
            }
        }
    }

    return $null
}

function Get-FirstExistingInstallPath {
    param([object]$App)

    $paths = ConvertTo-StringArray (Get-ConfigValue -Object $App -Name "installPaths" -Default @())
    foreach ($pathTemplate in $paths) {
        $path = [Environment]::ExpandEnvironmentVariables($pathTemplate)
        if ($path -match "[\*\?]") {
            $match = Get-ChildItem -Path $path -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($null -ne $match) {
                return $match.FullName
            }
            continue
        }

        if (Test-Path -LiteralPath $path) {
            return $path
        }
    }

    return $null
}

function Get-FileVersionFromPath {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    try {
        $item = Get-Item -LiteralPath $Path -ErrorAction Stop
        if ($item.PSIsContainer) {
            return $null
        }

        $version = $item.VersionInfo.ProductVersion
        if ([string]::IsNullOrWhiteSpace($version)) {
            $version = $item.VersionInfo.FileVersion
        }

        return (Get-VersionFromText -Text $version)
    } catch {
        return $null
    }
}

function Get-AppVersion {
    param(
        [object]$App,
        [string]$CommandOutput = "",
        [object]$RegistryResult = $null,
        [string]$InstallPath = ""
    )

    $versionFromOutput = Get-VersionFromText -Text $CommandOutput
    if (-not [string]::IsNullOrWhiteSpace($versionFromOutput)) {
        return $versionFromOutput
    }

    $versionCommand = [string](Get-ConfigValue -Object $App -Name "versionCommand" -Default "")
    if (-not [string]::IsNullOrWhiteSpace($versionCommand)) {
        $commandResult = Invoke-CommandText -CommandText $versionCommand -TimeoutSeconds 30
        if ($commandResult.ExitCode -eq 0) {
            $version = Get-VersionFromText -Text $commandResult.Output
            if (-not [string]::IsNullOrWhiteSpace($version)) {
                return $version
            }
        }
    }

    if ($null -ne $RegistryResult) {
        $registryVersion = [string](Get-ConfigValue -Object $RegistryResult -Name "DisplayVersion" -Default "")
        $version = Get-VersionFromText -Text $registryVersion
        if (-not [string]::IsNullOrWhiteSpace($version)) {
            return $version
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($InstallPath)) {
        $fileVersion = Get-FileVersionFromPath -Path $InstallPath
        if (-not [string]::IsNullOrWhiteSpace($fileVersion)) {
            return $fileVersion
        }
    }

    return $null
}

function Test-AppInstalled {
    param([object]$App)

    $appName = [string](Get-ConfigValue -Object $App -Name "name" -Default "未命名软件")
    $checkCommands = ConvertTo-StringArray (Get-ConfigValue -Object $App -Name "checkCommands" -Default @())

    foreach ($command in $checkCommands) {
        try {
            $result = Invoke-CommandText -CommandText $command -TimeoutSeconds 30
            if ($result.ExitCode -eq 0) {
                $version = Get-AppVersion -App $App -CommandOutput $result.Output
                return [PSCustomObject]@{
                    Installed = $true
                    Version = $version
                    VersionKnown = (-not [string]::IsNullOrWhiteSpace($version))
                    Source = "命令检测：$command"
                    Detail = $result.Output
                    Registry = $null
                    InstallPath = ""
                }
            }
        } catch {
            Write-Log -Message "[警告] $appName 命令检测失败：$command，原因：$($_.Exception.Message)" -Level "WARN"
        }
    }

    $appxNames = ConvertTo-StringArray (Get-ConfigValue -Object $App -Name "appxNames" -Default @())
    $appxResult = Get-InstalledAppByAppx -AppxNames $appxNames
    if ($null -ne $appxResult) {
        $version = Get-VersionFromText -Text $appxResult.Version
        return [PSCustomObject]@{
            Installed = $true
            Version = $version
            VersionKnown = (-not [string]::IsNullOrWhiteSpace($version))
            Source = "Appx 包：$($appxResult.Name)"
            Detail = $appxResult.PackageFullName
            Registry = $null
            InstallPath = $appxResult.InstallLocation
        }
    }

    $registryNames = ConvertTo-StringArray (Get-ConfigValue -Object $App -Name "registryNames" -Default @())
    $registryExcludeNames = ConvertTo-StringArray (Get-ConfigValue -Object $App -Name "registryExcludeNames" -Default @())
    $registryResult = Get-InstalledAppByRegistry -RegistryNames $registryNames -ExcludeNames $registryExcludeNames
    if ($null -ne $registryResult) {
        $version = Get-AppVersion -App $App -RegistryResult $registryResult
        return [PSCustomObject]@{
            Installed = $true
            Version = $version
            VersionKnown = (-not [string]::IsNullOrWhiteSpace($version))
            Source = "注册表：$($registryResult.DisplayName)"
            Detail = $registryResult.RegistryPath
            Registry = $registryResult
            InstallPath = $registryResult.InstallLocation
        }
    }

    $processNames = ConvertTo-StringArray (Get-ConfigValue -Object $App -Name "processNames" -Default @())
    $processResult = Get-InstalledAppByProcess -ProcessNames $processNames
    if ($null -ne $processResult) {
        return [PSCustomObject]@{
            Installed = $true
            Version = $processResult.Version
            VersionKnown = (-not [string]::IsNullOrWhiteSpace($processResult.Version))
            Source = "进程检测：$($processResult.ProcessName)"
            Detail = $processResult.Path
            Registry = $null
            InstallPath = $processResult.Path
        }
    }

    $shortcutNames = ConvertTo-StringArray (Get-ConfigValue -Object $App -Name "shortcutNames" -Default @())
    $shortcutResult = Get-InstalledAppByShortcut -ShortcutNames $shortcutNames
    if ($null -ne $shortcutResult) {
        return [PSCustomObject]@{
            Installed = $true
            Version = $shortcutResult.Version
            VersionKnown = (-not [string]::IsNullOrWhiteSpace($shortcutResult.Version))
            Source = "快捷方式：$($shortcutResult.Name)"
            Detail = $shortcutResult.LinkPath
            Registry = $null
            InstallPath = $shortcutResult.TargetPath
        }
    }

    $installPath = Get-FirstExistingInstallPath -App $App
    if (-not [string]::IsNullOrWhiteSpace($installPath)) {
        $version = Get-AppVersion -App $App -InstallPath $installPath
        return [PSCustomObject]@{
            Installed = $true
            Version = $version
            VersionKnown = (-not [string]::IsNullOrWhiteSpace($version))
            Source = "路径检测：$installPath"
            Detail = $installPath
            Registry = $null
            InstallPath = $installPath
        }
    }

    return [PSCustomObject]@{
        Installed = $false
        Version = $null
        VersionKnown = $false
        Source = "未检测到"
        Detail = ""
        Registry = $null
        InstallPath = ""
    }
}

function Compare-VersionRequirement {
    param(
        [string]$CurrentVersion,
        [object]$App
    )

    $required = ([string](Get-ConfigValue -Object $App -Name "requiredVersion" -Default "")).Trim()
    $targetMajorValue = Get-ConfigValue -Object $App -Name "targetMajorVersion" -Default $null

    if ([string]::IsNullOrWhiteSpace($required) -and $null -eq $targetMajorValue) {
        return [PSCustomObject]@{ State = "Satisfied"; Message = "仅检测是否安装"; NeedUpgrade = $false }
    }

    if ([string]::IsNullOrWhiteSpace($CurrentVersion)) {
        return [PSCustomObject]@{ State = "Unknown"; Message = "版本未知"; NeedUpgrade = $false }
    }

    $currentClean = Get-VersionFromText -Text $CurrentVersion
    if ([string]::IsNullOrWhiteSpace($currentClean)) {
        return [PSCustomObject]@{ State = "Unknown"; Message = "版本无法解析"; NeedUpgrade = $false }
    }

    if ($null -ne $targetMajorValue -and "$targetMajorValue" -match "^\d+$") {
        $targetMajor = [int]$targetMajorValue
        $currentMajor = [int](($currentClean -split "\.")[0])
        if ($currentMajor -eq $targetMajor) {
            return [PSCustomObject]@{
                State = "Satisfied"
                Message = "当前主版本：$currentMajor；目标主版本：$targetMajor；是否符合要求：是"
                NeedUpgrade = $false
            }
        }

        return [PSCustomObject]@{
            State = "NotSatisfied"
            Message = "当前主版本：$currentMajor；目标主版本：$targetMajor；是否符合要求：否"
            NeedUpgrade = $true
        }
    }

    if ($required -match "^(最新本地安装包|latest-local|local-latest|LTS)$") {
        return [PSCustomObject]@{
            State = "Satisfied"
            Message = "当前版本：$currentClean；目标版本以本地安装包为准，未配置具体版本，默认不重复覆盖安装"
            NeedUpgrade = $false
        }
    }

    if ($required -match "^\s*>=\s*(.+)$") {
        $requiredVersion = ConvertTo-VersionObject -VersionText $Matches[1]
        $currentVersion = ConvertTo-VersionObject -VersionText $currentClean
        if ($null -eq $requiredVersion -or $null -eq $currentVersion) {
            return [PSCustomObject]@{ State = "Unknown"; Message = "版本比较失败"; NeedUpgrade = $false }
        }
        if ($currentVersion -ge $requiredVersion) {
            return [PSCustomObject]@{ State = "Satisfied"; Message = "版本满足要求"; NeedUpgrade = $false }
        }
        return [PSCustomObject]@{ State = "NotSatisfied"; Message = "当前版本低于 $required"; NeedUpgrade = $true }
    }

    if ($required -match "x") {
        $requiredParts = @($required -split "\.")
        $currentParts = @($currentClean -split "\.")
        for ($i = 0; $i -lt $requiredParts.Count; $i++) {
            $part = $requiredParts[$i]
            if ($part -eq "x" -or $part -eq "*") {
                continue
            }
            if ($currentParts.Count -le $i -or $currentParts[$i] -ne $part) {
                return [PSCustomObject]@{ State = "NotSatisfied"; Message = "当前版本 $currentClean 不符合 $required"; NeedUpgrade = $true }
            }
        }
        return [PSCustomObject]@{ State = "Satisfied"; Message = "版本符合 $required"; NeedUpgrade = $false }
    }

    $requiredVersionObject = ConvertTo-VersionObject -VersionText $required
    $currentVersionObject = ConvertTo-VersionObject -VersionText $currentClean
    if ($null -eq $requiredVersionObject -or $null -eq $currentVersionObject) {
        return [PSCustomObject]@{ State = "Unknown"; Message = "版本比较失败"; NeedUpgrade = $false }
    }

    if ($currentVersionObject -ge $requiredVersionObject) {
        return [PSCustomObject]@{ State = "Satisfied"; Message = "版本满足要求"; NeedUpgrade = $false }
    }

    return [PSCustomObject]@{ State = "NotSatisfied"; Message = "当前版本低于目标版本 $required"; NeedUpgrade = $true }
}

function Get-TargetVersionText {
    param([object]$App)

    $required = [string](Get-ConfigValue -Object $App -Name "requiredVersion" -Default "")
    $targetMajor = Get-ConfigValue -Object $App -Name "targetMajorVersion" -Default $null
    $managedBy = [string](Get-ConfigValue -Object $App -Name "managedBy" -Default "")

    if (-not [string]::IsNullOrWhiteSpace($managedBy)) {
        return "随 $managedBy 安装"
    }

    if (-not [string]::IsNullOrWhiteSpace($required)) {
        if ($null -ne $targetMajor -and "$targetMajor" -ne "") {
            return "$required（目标主版本 $targetMajor）"
        }
        return $required
    }

    return "仅检测是否安装"
}

function Get-Installable {
    param([object]$App)

    $type = ([string](Get-ConfigValue -Object $App -Name "type" -Default "")).ToLowerInvariant()
    $installer = [string](Get-ConfigValue -Object $App -Name "installer" -Default "")
    $configured = Get-BoolConfig -Object $App -Name "installable" -Default $true

    if (-not $configured) {
        return $false
    }
    if ($type -eq "none" -or [string]::IsNullOrWhiteSpace($installer)) {
        return $false
    }

    return $true
}

function Test-OnlineStubInstaller {
    param([object]$App)

    $installerKind = ([string](Get-ConfigValue -Object $App -Name "installerKind" -Default "")).Trim().ToLowerInvariant()
    if ($installerKind -eq "online_stub") {
        return $true
    }

    return $false
}

function Get-ManualInstallReason {
    param([object]$App)

    $name = [string](Get-ConfigValue -Object $App -Name "name" -Default "未命名软件")

    if (Test-OnlineStubInstaller -App $App) {
        $requiresStoreInstaller = Get-BoolConfig -Object $App -Name "requiresStoreInstaller" -Default $false
        if ($requiresStoreInstaller) {
            return "安装包是 Store Installer 在线引导器，可能需要联网或 Microsoft Store 组件，不执行静默自动安装。"
        }

        return "安装包疑似在线引导器，可能需要联网，不执行静默自动安装。"
    }

    $autoInstallEnabled = Get-BoolConfig -Object $App -Name "autoInstallEnabled" -Default $true
    $requireManualConfirm = Get-BoolConfig -Object $App -Name "requireManualConfirmBeforeInstall" -Default $false

    if (-not $autoInstallEnabled -or $requireManualConfirm) {
        if ($name -eq "ToDesk") {
            return "ToDesk 是远控软件，静默安装参数不可靠，建议人工安装。"
        }

        return "该软件配置为需要人工确认，默认不执行静默自动安装。"
    }

    return ""
}

function Test-AppInstallerReady {
    param([object]$App)

    $installerName = [string](Get-ConfigValue -Object $App -Name "installer" -Default "")
    if ([string]::IsNullOrWhiteSpace($installerName)) {
        return [PSCustomObject]@{
            Ready = $false
            Path = ""
            Message = "未配置安装包文件名"
        }
    }

    if (-not (Test-Path -LiteralPath $Script:InstallersDir)) {
        return [PSCustomObject]@{
            Ready = $false
            Path = $Script:InstallersDir
            Message = "installers 目录不存在：$Script:InstallersDir"
        }
    }

    $installerPath = Join-Path $Script:InstallersDir $installerName
    if (-not (Test-Path -LiteralPath $installerPath)) {
        return [PSCustomObject]@{
            Ready = $false
            Path = $installerPath
            Message = "找不到安装包：$installerPath"
        }
    }

    return [PSCustomObject]@{
        Ready = $true
        Path = $installerPath
        Message = "安装包已就绪：$installerPath"
    }
}

function Invoke-InstallerProcess {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string]$Arguments = "",
        [int]$TimeoutMinutes = 20
    )

    $timeoutMs = [int]([TimeSpan]::FromMinutes($TimeoutMinutes).TotalMilliseconds)
    $displayCommand = if ([string]::IsNullOrWhiteSpace($Arguments)) { "`"$FilePath`"" } else { "`"$FilePath`" $Arguments" }
    Write-Log -Message "[执行] $displayCommand" -Level "INFO"

    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $FilePath
        $psi.Arguments = $Arguments
        $psi.WorkingDirectory = Split-Path -Parent $FilePath
        $psi.UseShellExecute = $false

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $psi
        [void]$process.Start()

        if (-not $process.WaitForExit($timeoutMs)) {
            try {
                $process.Kill()
            } catch {
                Write-Log -Message "[警告] 安装超时后尝试结束进程失败：$($_.Exception.Message)" -Level "WARN"
            }

            return [PSCustomObject]@{
                Success = $false
                ExitCode = 124
                Message = "安装程序超时（${TimeoutMinutes} 分钟）"
            }
        }

        $exitCode = $process.ExitCode
        if ($exitCode -eq 0 -or $exitCode -eq 3010) {
            $message = if ($exitCode -eq 3010) { "安装完成，系统提示需要重启后完全生效" } else { "安装程序返回成功" }
            return [PSCustomObject]@{
                Success = $true
                ExitCode = $exitCode
                Message = $message
            }
        }

        return [PSCustomObject]@{
            Success = $false
            ExitCode = $exitCode
            Message = "安装程序返回非 0 代码：$exitCode"
        }
    } catch {
        return [PSCustomObject]@{
            Success = $false
            ExitCode = 1
            Message = "启动安装程序失败：$($_.Exception.Message)"
        }
    }
}

function Install-App {
    param(
        [object]$App,
        [string]$Action = "安装"
    )

    $appName = [string](Get-ConfigValue -Object $App -Name "name" -Default "未命名软件")
    $installerName = [string](Get-ConfigValue -Object $App -Name "installer" -Default "")
    $type = ([string](Get-ConfigValue -Object $App -Name "type" -Default "exe")).ToLowerInvariant()
    $timeout = [int](Get-ConfigValue -Object $Script:Config.settings -Name "installTimeoutMinutes" -Default 20)

    $manualReason = Get-ManualInstallReason -App $App
    if (-not [string]::IsNullOrWhiteSpace($manualReason)) {
        $reason = $manualReason
        Write-Log -Message "[跳过] $appName：$reason" -Level "WARN"
        return [PSCustomObject]@{ Success = $false; Attempted = $false; ExitCode = 1; Message = $reason }
    }

    if (-not (Get-Installable -App $App)) {
        $managedBy = [string](Get-ConfigValue -Object $App -Name "managedBy" -Default "")
        $reason = if ([string]::IsNullOrWhiteSpace($managedBy)) { "未配置安装包，无法自动安装" } else { "该组件随 $managedBy 安装，不单独安装" }
        Write-Log -Message "[跳过] $appName：$reason" -Level "WARN"
        return [PSCustomObject]@{ Success = $false; Attempted = $false; ExitCode = 1; Message = $reason }
    }

    if (-not (Test-Path -LiteralPath $Script:InstallersDir)) {
        return [PSCustomObject]@{ Success = $false; Attempted = $false; ExitCode = 1; Message = "installers 目录不存在：$Script:InstallersDir" }
    }

    $installerPath = Join-Path $Script:InstallersDir $installerName
    if (-not (Test-Path -LiteralPath $installerPath)) {
        return [PSCustomObject]@{ Success = $false; Attempted = $false; ExitCode = 1; Message = "找不到安装包：$installerPath" }
    }

    $attempts = @()
    $silentArgs = @(ConvertTo-StringArray (Get-ConfigValue -Object $App -Name "silentArgs" -Default @()))
    $fallbackArgs = ConvertTo-StringArray (Get-ConfigValue -Object $App -Name "fallbackArgs" -Default @())

    if ($type -eq "msi") {
        if ($silentArgs.Count -eq 0) {
            $silentArgs = @("/qn /norestart")
        }
        foreach ($arg in $silentArgs) {
            $attempts += [PSCustomObject]@{
                Label = "静默安装"
                FilePath = "msiexec.exe"
                Arguments = "/i `"$installerPath`" $arg"
            }
        }
        foreach ($arg in $fallbackArgs) {
            $attempts += [PSCustomObject]@{
                Label = "备用参数"
                FilePath = "msiexec.exe"
                Arguments = "/i `"$installerPath`" $arg"
            }
        }
    } else {
        foreach ($arg in $silentArgs) {
            $attempts += [PSCustomObject]@{
                Label = "静默安装"
                FilePath = $installerPath
                Arguments = $arg
            }
        }
        foreach ($arg in $fallbackArgs) {
            $attempts += [PSCustomObject]@{
                Label = "备用参数"
                FilePath = $installerPath
                Arguments = $arg
            }
        }
    }

    if ($attempts.Count -eq 0) {
        return [PSCustomObject]@{ Success = $false; Attempted = $false; ExitCode = 1; Message = "未配置 silentArgs 或 fallbackArgs，为避免卡住，不执行交互式安装" }
    }

    $lastResult = $null
    foreach ($attempt in $attempts) {
        Write-Log -Message "[$Action] $appName：尝试 $($attempt.Label)" -Level "INFO"
        $result = Invoke-InstallerProcess -FilePath $attempt.FilePath -Arguments $attempt.Arguments -TimeoutMinutes $timeout
        $lastResult = $result

        if ($result.Success) {
            return [PSCustomObject]@{
                Success = $true
                Attempted = $true
                ExitCode = $result.ExitCode
                Message = "$($attempt.Label)成功：$($result.Message)"
            }
        }

        Write-Log -Message "[失败] $appName：$($attempt.Label)失败，$($result.Message)" -Level "WARN"
    }

    return [PSCustomObject]@{
        Success = $false
        Attempted = $true
        ExitCode = $lastResult.ExitCode
        Message = "所有安装参数均失败，最后错误：$($lastResult.Message)"
    }
}

function Refresh-EnvironmentPath {
    param([switch]$AddKnownToolPaths)

    Write-Log -Message "[环境变量] 正在刷新当前 PowerShell 会话 PATH..." -Level "INFO"

    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $paths = @()

    foreach ($pathBlock in @($machinePath, $userPath)) {
        if (-not [string]::IsNullOrWhiteSpace($pathBlock)) {
            $paths += @($pathBlock -split ";" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        }
    }

    if ($AddKnownToolPaths) {
        $knownPaths = @(
            "%ProgramFiles%\nodejs",
            "%ProgramFiles(x86)%\nodejs",
            "%LOCALAPPDATA%\Programs\Python\Python312",
            "%LOCALAPPDATA%\Programs\Python\Python312\Scripts",
            "%ProgramFiles%\Python312",
            "%ProgramFiles%\Python312\Scripts",
            "%ProgramFiles(x86)%\Python312",
            "%ProgramFiles(x86)%\Python312\Scripts",
            "%APPDATA%\npm",
            "%ProgramFiles%\Git\cmd",
            "%ProgramFiles%\Git\bin",
            "%ProgramFiles(x86)%\Git\cmd",
            "%ProgramFiles(x86)%\Git\bin",
            "%LOCALAPPDATA%\Programs\Git\cmd"
        )

        foreach ($pathTemplate in $knownPaths) {
            $expanded = [Environment]::ExpandEnvironmentVariables($pathTemplate)
            if (Test-Path -LiteralPath $expanded) {
                $paths += $expanded
            }
        }
    }

    $uniquePaths = New-Object System.Collections.Generic.List[string]
    foreach ($path in $paths) {
        $expandedPath = [Environment]::ExpandEnvironmentVariables($path.Trim())
        if ([string]::IsNullOrWhiteSpace($expandedPath)) {
            continue
        }

        $exists = $false
        foreach ($item in $uniquePaths) {
            if ($item.Equals($expandedPath, [StringComparison]::OrdinalIgnoreCase)) {
                $exists = $true
                break
            }
        }

        if (-not $exists) {
            $uniquePaths.Add($expandedPath) | Out-Null
        }
    }

    $env:Path = ($uniquePaths -join ";")
    Write-Log -Message "[环境变量] 当前会话 PATH 已刷新。" -Level "SUCCESS"

    foreach ($command in @("python --version", "node -v", "npm -v", "git --version")) {
        $result = Invoke-CommandText -CommandText $command -TimeoutSeconds 20
        if ($result.ExitCode -eq 0) {
            Write-Log -Message "[检测] $command => $($result.Output)" -Level "SUCCESS"
        } else {
            Write-Log -Message "[检测] $command 未通过：$($result.Error) $($result.Output)" -Level "WARN"
        }
    }
}

function Escape-MarkdownCell {
    param([object]$Value)

    if ($null -eq $Value) {
        return "-"
    }

    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) {
        return "-"
    }

    return ($text -replace "\|", "\|" -replace "`r?`n", "<br>")
}

function Generate-Report {
    param(
        [object[]]$Results,
        [string]$OperationName = "环境检测"
    )

    $info = Get-SystemInfo
    $lines = New-Object System.Collections.Generic.List[string]

    $lines.Add("# AI 开发环境初始化报告") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("运行时间：$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))") | Out-Null
    $lines.Add("执行操作：$OperationName") | Out-Null
    $lines.Add("电脑名称：$($info.ComputerName)") | Out-Null
    $lines.Add("当前用户：$($info.UserName)") | Out-Null
    $lines.Add("U 盘/工具路径：$($info.BaseDir)") | Out-Null
    $lines.Add("脚本路径：$($info.ScriptPath)") | Out-Null
    $lines.Add("日志路径：$($info.LogPath)") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("## 硬件巡检信息") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("- 电脑品牌：$($info.ComputerBrand)") | Out-Null
    $lines.Add("- 电脑型号：$($info.ComputerModel)") | Out-Null
    $lines.Add("- Windows 版本：$($info.WindowsVersion)") | Out-Null
    $lines.Add("- CPU：$($info.CpuName)") | Out-Null
    $lines.Add("- CPU 核心/线程：$($info.CpuCores) 核 / $($info.CpuThreads) 线程") | Out-Null
    $lines.Add("- 总内存：$($info.TotalMemory)") | Out-Null
    $lines.Add("- 可用内存：$($info.FreeMemory)") | Out-Null
    $lines.Add("- 系统盘剩余空间：$($info.SystemDiskFree)") | Out-Null
    $lines.Add("- 工具所在盘剩余空间：$($info.ToolDiskFree)") | Out-Null
    $lines.Add("- 显卡：$($info.GpuNames)") | Out-Null
    $lines.Add("- PowerShell 版本：$($info.PowerShellVersion)") | Out-Null
    $lines.Add("- 是否管理员权限：$(if ($info.IsAdmin) { '是' } else { '否' })") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("## 软件检查结果") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("| 软件 | 初始状态 | 初始版本 | 目标版本 | 执行动作 | 安装结果 | 最终状态 | 最终版本 | 备注 |") | Out-Null
    $lines.Add("| --- | --- | --- | --- | --- | --- | --- | --- | --- |") | Out-Null

    foreach ($result in $Results) {
        $lines.Add((
            "| {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7} | {8} |" -f
            (Escape-MarkdownCell $result.Name),
            (Escape-MarkdownCell $result.InitialStatus),
            (Escape-MarkdownCell $result.InitialVersion),
            (Escape-MarkdownCell $result.TargetVersion),
            (Escape-MarkdownCell $result.Action),
            (Escape-MarkdownCell $result.InstallResult),
            (Escape-MarkdownCell $result.FinalStatus),
            (Escape-MarkdownCell $result.FinalVersion),
            (Escape-MarkdownCell $result.Note)
        )) | Out-Null
    }

    $lines.Add("") | Out-Null
    $lines.Add("## 汇总") | Out-Null
    $lines.Add("") | Out-Null
    if ($Results.Count -gt 0 -and @($Results | Where-Object { $_.Action -ne "仅检测" }).Count -eq 0) {
        $summary = Get-CheckSummary -Results $Results
        $lines.Add("- 已安装：$($summary.Installed)") | Out-Null
        $lines.Add("- 未安装：$($summary.NotInstalled)") | Out-Null
        $lines.Add("- 需升级：$($summary.NeedUpgrade)") | Out-Null
        $lines.Add("- 版本未知：$($summary.VersionUnknown)") | Out-Null
        $lines.Add("- 异常：$($summary.Abnormal)") | Out-Null
    } else {
        $lines.Add("- 成功：$(@($Results | Where-Object { $_.InstallResult -eq '成功' -and $_.Action -ne '跳过' }).Count)") | Out-Null
        $lines.Add("- 跳过：$(@($Results | Where-Object { $_.Action -eq '跳过' }).Count)") | Out-Null
        $lines.Add("- 人工确认：$(@($Results | Where-Object { $_.Action -eq '人工确认' -or $_.InstallResult -eq '人工确认' }).Count)") | Out-Null
        $lines.Add("- 失败：$(@($Results | Where-Object { $_.InstallResult -eq '失败' }).Count)") | Out-Null
    }

    Set-Content -LiteralPath $Script:ReportPath -Value $lines -Encoding UTF8
    $Script:LastReportPath = $Script:ReportPath
    Write-Log -Message "[报告] 已生成：$Script:ReportPath" -Level "SUCCESS"
    return $Script:ReportPath
}

function New-AppRunResult {
    param(
        [object]$App,
        [object]$InitialDetection,
        [object]$FinalDetection,
        [string]$Action,
        [string]$InstallResult,
        [string]$Note = "",
        [string]$RequirementState = ""
    )

    $name = [string](Get-ConfigValue -Object $App -Name "name" -Default "未命名软件")
    $initialStatus = if ($InitialDetection.Installed) {
        if ($InitialDetection.VersionKnown) { "已安装" } else { "已安装，版本未知" }
    } else {
        "未安装"
    }
    $finalStatus = if ($FinalDetection.Installed) {
        if ($FinalDetection.VersionKnown) { "已安装" } else { "已安装，版本未知" }
    } else {
        "未安装"
    }

    $initialVersion = if ($InitialDetection.VersionKnown) { $InitialDetection.Version } else { if ($InitialDetection.Installed) { "未知" } else { "-" } }
    $finalVersion = if ($FinalDetection.VersionKnown) { $FinalDetection.Version } else { if ($FinalDetection.Installed) { "未知" } else { "-" } }

    return [PSCustomObject]@{
        Name = $name
        InitialStatus = $initialStatus
        InitialVersion = $initialVersion
        TargetVersion = Get-TargetVersionText -App $App
        Action = $Action
        InstallResult = $InstallResult
        FinalStatus = $finalStatus
        FinalVersion = $finalVersion
        Note = $Note
        RequirementState = $RequirementState
    }
}

function Get-CheckSummary {
    param([object[]]$Results)

    return [PSCustomObject]@{
        Installed = @($Results | Where-Object { $_.InitialStatus -like "已安装*" }).Count
        NotInstalled = @($Results | Where-Object { $_.InitialStatus -eq "未安装" }).Count
        NeedUpgrade = @($Results | Where-Object { $_.RequirementState -eq "NotSatisfied" }).Count
        VersionUnknown = @($Results | Where-Object { $_.InitialStatus -like "*版本未知*" }).Count
        Abnormal = @($Results | Where-Object { $_.Action -eq "异常" -or $_.InstallResult -eq "失败" }).Count
    }
}

function Show-Summary {
    param([object[]]$Results)

    $success = @($Results | Where-Object { $_.InstallResult -eq "成功" -and $_.Action -ne "跳过" }).Count
    $skipped = @($Results | Where-Object { $_.Action -eq "跳过" }).Count
    $manualConfirm = @($Results | Where-Object { $_.Action -eq "人工确认" -or $_.InstallResult -eq "人工确认" }).Count
    $failed = @($Results | Where-Object { $_.InstallResult -eq "失败" }).Count

    Write-Host ""
    Write-Host "========================================="
    Write-Host "执行完成"
    Write-Host "========================================="
    Write-Host ""
    Write-Host "成功：$success" -ForegroundColor Green
    Write-Host "跳过：$skipped" -ForegroundColor Yellow
    Write-Host "人工确认：$manualConfirm" -ForegroundColor Yellow
    Write-Host "失败：$failed" -ForegroundColor Red
    Write-Host ""
    Write-Host "报告路径："
    Write-Host $Script:LastReportPath
    Write-Host ""
    Write-Host "日志路径："
    Write-Host $Script:LogPath
    Write-Host ""
}

function Show-CheckSummary {
    param([object[]]$Results)

    $summary = Get-CheckSummary -Results $Results

    Write-Host ""
    Write-Host "========================================="
    Write-Host "检查完成"
    Write-Host "========================================="
    Write-Host ""
    Write-Host "已安装：$($summary.Installed)" -ForegroundColor Green
    Write-Host "未安装：$($summary.NotInstalled)" -ForegroundColor Yellow
    Write-Host "需升级：$($summary.NeedUpgrade)" -ForegroundColor Yellow
    Write-Host "版本未知：$($summary.VersionUnknown)" -ForegroundColor Yellow
    Write-Host "异常：$($summary.Abnormal)" -ForegroundColor Red
    Write-Host ""
    Write-Host "报告路径："
    Write-Host $Script:LastReportPath
    Write-Host ""
    Write-Host "日志路径："
    Write-Host $Script:LogPath
    Write-Host ""
}

function Get-EnabledApps {
    $config = Load-Config
    return @($config.apps | Where-Object { Get-BoolConfig -Object $_ -Name "enabled" -Default $true })
}

function Run-CheckOnly {
    param([string]$OperationName = "仅检查电脑环境")

    Write-Log -Message "[开始] $OperationName" -Level "INFO"
    $results = @()
    $apps = Get-EnabledApps

    foreach ($app in $apps) {
        $name = [string](Get-ConfigValue -Object $app -Name "name" -Default "未命名软件")
        Write-Log -Message "[检查] $name..." -Level "INFO"
        $detection = Test-AppInstalled -App $app
        $compare = Compare-VersionRequirement -CurrentVersion $detection.Version -App $app

        if (-not $detection.Installed) {
            Write-Log -Message "[发现] $name 未安装。" -Level "WARN"
        } elseif ($detection.VersionKnown) {
            Write-Log -Message "[发现] $name 当前版本 $($detection.Version)，$($compare.Message)。" -Level "INFO"
        } else {
            Write-Log -Message "[发现] $name 已安装，但版本未知。" -Level "WARN"
        }

        $note = "$($detection.Source)；$($compare.Message)"
        $results += New-AppRunResult -App $app -InitialDetection $detection -FinalDetection $detection -Action "仅检测" -InstallResult "未执行" -Note $note -RequirementState $compare.State
    }

    $Script:LastResults = $results
    $Script:LastOperation = $OperationName
    Generate-Report -Results $results -OperationName $OperationName | Out-Null
    Show-CheckSummary -Results $results
}

function Run-InstallOrUpgrade {
    Write-Log -Message "[开始] 一键安装 / 升级所有软件" -Level "INFO"
    $results = @()
    $apps = Get-EnabledApps

    if (-not (Test-Path -LiteralPath $Script:InstallersDir)) {
        Write-Log -Message "[错误] installers 目录不存在：$Script:InstallersDir" -Level "ERROR"
    }

    foreach ($app in $apps) {
        $name = [string](Get-ConfigValue -Object $app -Name "name" -Default "未命名软件")
        Write-Log -Message "[检查] $name..." -Level "INFO"

        $initial = Test-AppInstalled -App $app
        $compare = Compare-VersionRequirement -CurrentVersion $initial.Version -App $app
        $forceUnknown = Get-BoolConfig -Object $app -Name "forceUpgradeWhenVersionUnknown" -Default $false
        $installable = Get-Installable -App $app
        $action = "跳过"
        $shouldInstall = $false
        $note = "$($initial.Source)；$($compare.Message)"

        if (-not $initial.Installed) {
            if ($installable) {
                $action = "安装"
                $shouldInstall = $true
                Write-Log -Message "[发现] $name 未安装，需要安装。" -Level "WARN"
            } else {
                $action = "失败"
                $managedBy = [string](Get-ConfigValue -Object $app -Name "managedBy" -Default "")
                $reason = if ([string]::IsNullOrWhiteSpace($managedBy)) { "未安装，且未配置独立安装包" } else { "未检测到，通常应随 $managedBy 安装" }
                Write-Log -Message "[失败] $name：$reason" -Level "ERROR"
                $results += New-AppRunResult -App $app -InitialDetection $initial -FinalDetection $initial -Action $action -InstallResult "失败" -Note $reason
                continue
            }
        } elseif ($compare.State -eq "Satisfied") {
            Write-Log -Message "[跳过] $name 已满足要求。" -Level "SUCCESS"
            $results += New-AppRunResult -App $app -InitialDetection $initial -FinalDetection $initial -Action "跳过" -InstallResult "跳过" -Note $note
            continue
        } elseif ($compare.State -eq "NotSatisfied") {
            if ($installable) {
                $action = "升级"
                $shouldInstall = $true
                Write-Log -Message "[发现] $name 当前版本 $($initial.Version)，需要升级到 $(Get-TargetVersionText -App $app)。" -Level "WARN"
            } else {
                $reason = "版本不满足要求，但该组件不支持独立安装。"
                Write-Log -Message "[失败] $name：$reason" -Level "ERROR"
                $results += New-AppRunResult -App $app -InitialDetection $initial -FinalDetection $initial -Action "失败" -InstallResult "失败" -Note $reason
                continue
            }
        } else {
            if ($forceUnknown -and $installable) {
                $action = "覆盖安装"
                $shouldInstall = $true
                Write-Log -Message "[升级] $name 版本未知或无法比较，根据配置执行覆盖安装。" -Level "WARN"
            } else {
                Write-Log -Message "[跳过] $name 已安装，但版本未知；配置未要求覆盖安装。" -Level "WARN"
                $results += New-AppRunResult -App $app -InitialDetection $initial -FinalDetection $initial -Action "跳过" -InstallResult "跳过" -Note $note
                continue
            }
        }

        if (-not $shouldInstall) {
            $results += New-AppRunResult -App $app -InitialDetection $initial -FinalDetection $initial -Action "跳过" -InstallResult "跳过" -Note $note
            continue
        }

        $manualInstallReason = Get-ManualInstallReason -App $app
        if (-not [string]::IsNullOrWhiteSpace($manualInstallReason)) {
            Write-Log -Message "[人工确认] $name：$manualInstallReason" -Level "WARN"
            $results += New-AppRunResult -App $app -InitialDetection $initial -FinalDetection $initial -Action "人工确认" -InstallResult "人工确认" -Note $manualInstallReason
            continue
        }

        $installerReady = Test-AppInstallerReady -App $app
        if (-not $installerReady.Ready) {
            Write-Log -Message "[失败] $name：$($installerReady.Message)" -Level "ERROR"
            $results += New-AppRunResult -App $app -InitialDetection $initial -FinalDetection $initial -Action $action -InstallResult "失败" -Note $installerReady.Message
            continue
        }

        $installResult = Install-App -App $app -Action $action

        if (-not $installResult.Attempted) {
            Write-Log -Message "[失败] $name：$($installResult.Message)" -Level "ERROR"
            $results += New-AppRunResult -App $app -InitialDetection $initial -FinalDetection $initial -Action $action -InstallResult "失败" -Note $installResult.Message
            continue
        }

        if ($installResult.Success -and (Get-BoolConfig -Object $app -Name "refreshPathAfterInstall" -Default $false)) {
            Refresh-EnvironmentPath -AddKnownToolPaths
        }

        Write-Log -Message "[复检] $name..." -Level "INFO"
        $final = Test-AppInstalled -App $app
        $finalCompare = Compare-VersionRequirement -CurrentVersion $final.Version -App $app

        if ($installResult.Success -and $final.Installed -and $finalCompare.State -ne "NotSatisfied") {
            Write-Log -Message "[成功] $name 处理完成。" -Level "SUCCESS"
            $results += New-AppRunResult -App $app -InitialDetection $initial -FinalDetection $final -Action $action -InstallResult "成功" -Note $installResult.Message
        } else {
            $failureReason = $installResult.Message
            if ($installResult.Success -and -not $final.Installed) {
                $failureReason = "安装程序返回成功，但复检未确认已安装。"
            } elseif ($installResult.Success -and $finalCompare.State -eq "NotSatisfied") {
                $failureReason = "安装程序返回成功，但复检版本仍不满足要求：$($finalCompare.Message)"
            }

            Write-Log -Message "[失败] $name：$failureReason" -Level "ERROR"
            $results += New-AppRunResult -App $app -InitialDetection $initial -FinalDetection $final -Action $action -InstallResult "失败" -Note $failureReason
        }
    }

    $Script:LastResults = $results
    $Script:LastOperation = "一键安装 / 升级所有软件"
    Generate-Report -Results $results -OperationName $Script:LastOperation | Out-Null
    Show-Summary -Results $results
}

function Run-RepairEnvironment {
    Write-Log -Message "[开始] 修复环境变量" -Level "INFO"
    Refresh-EnvironmentPath -AddKnownToolPaths
    Run-CheckOnly -OperationName "修复环境变量并检测"
}

function Export-CurrentReport {
    if ($Script:LastResults.Count -eq 0) {
        Write-Log -Message "[报告] 当前没有检测结果，先执行一次环境检测。" -Level "INFO"
        Run-CheckOnly -OperationName "导出环境报告"
        return
    }

    Generate-Report -Results $Script:LastResults -OperationName $Script:LastOperation | Out-Null
    Show-Summary -Results $Script:LastResults
}

function Write-UpdateLog {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS", "DEBUG")][string]$Level = "INFO",
        [switch]$NoConsole
    )

    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[{0}] [{1}] {2}" -f $time, $Level, $Message

    if (-not [string]::IsNullOrWhiteSpace($Script:UpdateLogPath)) {
        try {
            Add-Content -LiteralPath $Script:UpdateLogPath -Value $line -Encoding UTF8
        } catch {
            Write-Host "[更新日志错误] 无法写入日志：$($_.Exception.Message)" -ForegroundColor Red
        }
    }

    if (-not $NoConsole) {
        switch ($Level) {
            "WARN"    { Write-Host $Message -ForegroundColor Yellow }
            "ERROR"   { Write-Host $Message -ForegroundColor Red }
            "SUCCESS" { Write-Host $Message -ForegroundColor Green }
            "DEBUG"   { Write-Host $Message -ForegroundColor DarkGray }
            default   { Write-Host $Message }
        }
    }
}

function Invoke-UpdateCommandText {
    param(
        [Parameter(Mandatory = $true)][string]$CommandText,
        [int]$TimeoutSeconds = 60
    )

    Write-UpdateLog -Message "[只读命令] $CommandText" -Level "DEBUG" -NoConsole

    $job = Start-Job -ScriptBlock {
        param([string]$CommandText)

        try {
            $output = & cmd.exe /d /s /c $CommandText 2>&1
            $exitCode = $LASTEXITCODE
            [PSCustomObject]@{
                ExitCode = $exitCode
                Output = (($output | Out-String).Trim())
                TimedOut = $false
                Error = ""
            }
        } catch {
            [PSCustomObject]@{
                ExitCode = 1
                Output = ""
                TimedOut = $false
                Error = $_.Exception.Message
            }
        }
    } -ArgumentList $CommandText

    try {
        $completed = Wait-Job -Job $job -Timeout $TimeoutSeconds
        if ($null -eq $completed) {
            Stop-Job -Job $job -Force | Out-Null
            return [PSCustomObject]@{
                ExitCode = 124
                Output = ""
                TimedOut = $true
                Error = "命令执行超时（${TimeoutSeconds} 秒）"
            }
        }

        return Receive-Job -Job $job
    } finally {
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
    }
}

function Repair-MojibakeText {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $Text
    }

    if ($Text -notmatch "[鎵涓鍒鐨杈寘绋瀹厤]") {
        return $Text
    }

    try {
        $bytes = [System.Text.Encoding]::Default.GetBytes($Text)
        $fixed = [System.Text.Encoding]::UTF8.GetString($bytes)
        if (-not [string]::IsNullOrWhiteSpace($fixed)) {
            return $fixed
        }
    } catch {
        return $Text
    }

    return $Text
}

function Normalize-WingetOutput {
    param([string]$Text)

    $fixed = Repair-MojibakeText -Text $Text
    if ([string]::IsNullOrWhiteSpace($fixed)) {
        return ""
    }

    $lines = @()
    foreach ($line in ($fixed -split "`r?`n")) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed)) {
            continue
        }
        if ($trimmed -match "^[\-\|\\/]+$") {
            continue
        }
        $lines += $trimmed
    }

    return ($lines -join "`n")
}

function Invoke-WingetReadOnly {
    param(
        [string]$Arguments = "",
        [int]$TimeoutSeconds = 60
    )

    $command = Get-Command "winget.exe" -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        return [PSCustomObject]@{
            ExitCode = 9009
            Output = ""
            TimedOut = $false
            Error = "winget.exe 不存在"
        }
    }

    Write-UpdateLog -Message "[只读命令] winget $Arguments" -Level "DEBUG" -NoConsole

    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $command.Source
        $psi.Arguments = $Arguments
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        try {
            $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
            $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8
        } catch {
            # Windows PowerShell 旧运行时可能不支持该属性，忽略后走默认编码。
        }

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $psi
        [void]$process.Start()
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()

        if (-not $process.WaitForExit([int]([TimeSpan]::FromSeconds($TimeoutSeconds).TotalMilliseconds))) {
            try { $process.Kill() } catch {}
            return [PSCustomObject]@{
                ExitCode = 124
                Output = ""
                TimedOut = $true
                Error = "winget 执行超时（${TimeoutSeconds} 秒）"
            }
        }

        $stdout = $stdoutTask.Result
        $stderr = $stderrTask.Result
        $combined = (($stdout, $stderr) -join "`n")

        return [PSCustomObject]@{
            ExitCode = $process.ExitCode
            Output = Normalize-WingetOutput -Text $combined
            TimedOut = $false
            Error = ""
        }
    } catch {
        return [PSCustomObject]@{
            ExitCode = 1
            Output = ""
            TimedOut = $false
            Error = $_.Exception.Message
        }
    }
}

function Load-UpdateConfig {
    param([switch]$NoConsole)

    if (-not (Test-Path -LiteralPath $Script:UpdateConfigPath)) {
        throw "找不到 update-config.json，路径：$Script:UpdateConfigPath"
    }

    try {
        Write-UpdateLog -Message "[配置] 读取 update-config.json：$Script:UpdateConfigPath" -Level "INFO" -NoConsole:$NoConsole
        $raw = Get-Content -LiteralPath $Script:UpdateConfigPath -Raw -Encoding UTF8
        $config = $raw | ConvertFrom-Json
    } catch {
        throw "update-config.json 格式错误或无法读取：$($_.Exception.Message)"
    }

    if ($null -eq $config.apps -or $config.apps.Count -eq 0) {
        throw "update-config.json 中没有 apps 配置项。"
    }

    return $config
}

function Test-WingetAvailable {
    $command = Get-Command "winget.exe" -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        Write-UpdateLog -Message "[winget] 未找到 winget.exe。" -Level "WARN"
        return [PSCustomObject]@{
            Available = $false
            Version = ""
            Message = "winget 不可用"
        }
    }

    $result = Invoke-WingetReadOnly -Arguments "--version" -TimeoutSeconds 30
    if ($result.ExitCode -eq 0) {
        Write-UpdateLog -Message "[winget] 可用：$($result.Output)" -Level "SUCCESS"
        return [PSCustomObject]@{
            Available = $true
            Version = $result.Output
            Message = "winget 可用"
        }
    }

    Write-UpdateLog -Message "[winget] 检测失败：$($result.Error) $($result.Output)" -Level "WARN"
    return [PSCustomObject]@{
        Available = $false
        Version = ""
        Message = "winget 检测失败"
    }
}

function Get-UpdateDetectMethods {
    param([object]$App)

    $detect = [string](Get-ConfigValue -Object $App -Name "currentVersionDetect" -Default "")
    if ([string]::IsNullOrWhiteSpace($detect)) {
        if (-not [string]::IsNullOrWhiteSpace([string](Get-ConfigValue -Object $App -Name "versionCommand" -Default ""))) {
            return @("command", "registry", "path")
        }
        return @("registry", "path")
    }

    return @($detect -split "[,;/| ]+" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.ToLowerInvariant() })
}

function Get-CurrentInstalledVersionForUpdate {
    param([object]$App)

    $name = [string](Get-ConfigValue -Object $App -Name "name" -Default "未命名软件")
    $methods = Get-UpdateDetectMethods -App $App
    Write-UpdateLog -Message "[检测] $name 当前版本，方式：$($methods -join ', ')" -Level "INFO"

    foreach ($method in $methods) {
        switch ($method) {
            "command" {
                $command = [string](Get-ConfigValue -Object $App -Name "versionCommand" -Default "")
                if ([string]::IsNullOrWhiteSpace($command)) {
                    Write-UpdateLog -Message "[跳过] $name 未配置 versionCommand。" -Level "DEBUG" -NoConsole
                    continue
                }

                $result = Invoke-UpdateCommandText -CommandText $command -TimeoutSeconds 30
                if ($result.ExitCode -eq 0) {
                    $version = Get-VersionFromText -Text $result.Output
                    if (-not [string]::IsNullOrWhiteSpace($version)) {
                        return [PSCustomObject]@{
                            Installed = $true
                            Version = $version
                            Source = "命令：$command"
                            Note = "命令检测成功"
                        }
                    }
                    Write-UpdateLog -Message "[警告] $name 命令可执行，但未解析到版本：$($result.Output)" -Level "WARN"
                } else {
                    Write-UpdateLog -Message "[警告] $name 命令检测失败：$command；$($result.Error) $($result.Output)" -Level "WARN"
                }
            }
            "appx" {
                $appxNames = ConvertTo-StringArray (Get-ConfigValue -Object $App -Name "appxNames" -Default @())
                $appxResult = Get-InstalledAppByAppx -AppxNames $appxNames
                if ($null -ne $appxResult) {
                    $version = Get-VersionFromText -Text $appxResult.Version
                    return [PSCustomObject]@{
                        Installed = $true
                        Version = $version
                        Source = "Appx：$($appxResult.Name)"
                        Note = $appxResult.PackageFullName
                    }
                }
            }
            "registry" {
                $registryNames = ConvertTo-StringArray (Get-ConfigValue -Object $App -Name "registryNames" -Default @())
                $registryResult = Get-InstalledAppByRegistry -RegistryNames $registryNames
                if ($null -ne $registryResult) {
                    $version = Get-VersionFromText -Text $registryResult.DisplayVersion
                    return [PSCustomObject]@{
                        Installed = $true
                        Version = $version
                        Source = "注册表：$($registryResult.DisplayName)"
                        Note = $registryResult.RegistryPath
                    }
                }
            }
            { $_ -in @("path", "file") } {
                $installPath = Get-FirstExistingInstallPath -App $App
                if (-not [string]::IsNullOrWhiteSpace($installPath)) {
                    $version = Get-FileVersionFromPath -Path $installPath
                    return [PSCustomObject]@{
                        Installed = $true
                        Version = $version
                        Source = "文件：$installPath"
                        Note = "文件版本检测"
                    }
                }
            }
        }
    }

    return [PSCustomObject]@{
        Installed = $false
        Version = ""
        Source = "未检测到"
        Note = "无法识别当前版本"
    }
}

function Get-LatestVersionByWinget {
    param(
        [object]$App,
        [object]$WingetInfo
    )

    $name = [string](Get-ConfigValue -Object $App -Name "name" -Default "未命名软件")
    $wingetId = [string](Get-ConfigValue -Object $App -Name "wingetId" -Default "")

    if (-not $WingetInfo.Available) {
        return [PSCustomObject]@{ LatestVersion = ""; UpdateState = "未知"; Note = "winget 不可用" }
    }
    if ([string]::IsNullOrWhiteSpace($wingetId)) {
        return [PSCustomObject]@{ LatestVersion = ""; UpdateState = "未知"; Note = "未配置 wingetId" }
    }

    Write-UpdateLog -Message "[winget] 查询 $name：$wingetId" -Level "INFO"
    $result = Invoke-WingetReadOnly -Arguments ("upgrade --id `"{0}`" --exact --disable-interactivity" -f $wingetId) -TimeoutSeconds 60
    Write-UpdateLog -Message "[winget] $name 返回码：$($result.ExitCode)" -Level "DEBUG" -NoConsole

    $output = [string]$result.Output
    $outputForMatch = $output
    if ([string]::IsNullOrWhiteSpace($outputForMatch)) {
        $outputForMatch = [string]$result.Error
    }

    if ($outputForMatch -match "(?i)no available upgrade|no applicable upgrade|no newer package|没有可用|找不到可用的升级|没有可用的较新的包版本|無可用") {
        $note = if ($name -eq "Python 3.12") { "当前未发现 3.12.x 可用更新" } else { "winget 未发现可用更新" }
        Write-UpdateLog -Message "[winget] $name 未发现可用更新。" -Level "INFO"
        return [PSCustomObject]@{ LatestVersion = ""; UpdateState = "否"; Note = $note }
    }

    if ($outputForMatch -match "(?i)no installed package|no installed package found|not installed|找不到与输入条件匹配的已安装程序包|未匹配到已安装|找不到.*已安装") {
        Write-UpdateLog -Message "[winget] $name 未匹配到已安装包。" -Level "WARN"
        return [PSCustomObject]@{ LatestVersion = ""; UpdateState = "未知"; Note = "winget 未匹配到已安装包" }
    }

    if ($result.ExitCode -ne 0) {
        Write-UpdateLog -Message "[winget] $name 查询未返回可解析结果，返回码：$($result.ExitCode)" -Level "WARN"
        if (-not [string]::IsNullOrWhiteSpace($outputForMatch)) {
            Write-UpdateLog -Message "[winget] $name 原始输出：$outputForMatch" -Level "DEBUG" -NoConsole
        }
        return [PSCustomObject]@{ LatestVersion = ""; UpdateState = "未知"; Note = "winget 查询失败，返回码 $($result.ExitCode)" }
    }

    foreach ($line in ($output -split "`r?`n")) {
        if ($line -match [regex]::Escape($wingetId)) {
            $parts = @($line -split "\s{2,}" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            if ($parts.Count -ge 4) {
                $available = $parts[$parts.Count - 2]
                $latest = Get-VersionFromText -Text $available
                if (-not [string]::IsNullOrWhiteSpace($latest)) {
                    return [PSCustomObject]@{ LatestVersion = $latest; UpdateState = "是"; Note = "winget 解析到可用版本：$available" }
                }
            }
        }
    }

    return [PSCustomObject]@{ LatestVersion = ""; UpdateState = "未知"; Note = "winget 输出无法自动解析" }
}

function Get-LatestVersionByGitHubRelease {
    param([object]$App)

    $name = [string](Get-ConfigValue -Object $App -Name "name" -Default "未命名软件")
    $repo = [string](Get-ConfigValue -Object $App -Name "githubRepo" -Default "")
    if ([string]::IsNullOrWhiteSpace($repo)) {
        return [PSCustomObject]@{ LatestVersion = ""; UpdateState = "未知"; Note = "未配置 GitHub 仓库" }
    }

    try {
        Write-UpdateLog -Message "[GitHub] 查询 $name：$repo latest release" -Level "INFO"
        $api = "https://api.github.com/repos/$repo/releases/latest"
        $release = Invoke-RestMethod -Uri $api -Headers @{ "User-Agent" = "AI-Environment-Update-Agent-v2.1" } -UseBasicParsing -TimeoutSec 30
        $tag = [string]$release.tag_name
        $version = Get-VersionFromText -Text $tag
        if ([string]::IsNullOrWhiteSpace($version)) {
            $version = $tag
        }
        return [PSCustomObject]@{ LatestVersion = $version; UpdateState = "未知"; Note = "GitHub latest：$tag" }
    } catch {
        Write-UpdateLog -Message "[GitHub] $name 查询失败：$($_.Exception.Message)" -Level "WARN"
        return [PSCustomObject]@{ LatestVersion = ""; UpdateState = "未知"; Note = "GitHub 查询失败：$($_.Exception.Message)" }
    }
}

function Compare-UpdateVersions {
    param(
        [string]$CurrentVersion,
        [string]$LatestVersion,
        [string]$FallbackState = "未知"
    )

    if ([string]::IsNullOrWhiteSpace($CurrentVersion) -or [string]::IsNullOrWhiteSpace($LatestVersion)) {
        return $FallbackState
    }

    $currentObject = ConvertTo-VersionObject -VersionText $CurrentVersion
    $latestObject = ConvertTo-VersionObject -VersionText $LatestVersion
    if ($null -eq $currentObject -or $null -eq $latestObject) {
        return $FallbackState
    }

    if ($latestObject -gt $currentObject) {
        return "是"
    }

    return "否"
}

function Get-UpdateSuggestion {
    param(
        [object]$App,
        [string]$UpdateAvailable,
        [string]$LatestVersion
    )

    $category = [string](Get-ConfigValue -Object $App -Name "category" -Default "")
    $risk = [string](Get-ConfigValue -Object $App -Name "riskLevel" -Default "")
    $sourceType = [string](Get-ConfigValue -Object $App -Name "officialSourceType" -Default "")

    if ($category -eq "C" -or $risk -eq "high") {
        return "只检测，不升级"
    }
    if ($UpdateAvailable -eq "是") {
        return "发现可能更新，后续阶段再下载/确认"
    }
    if ($UpdateAvailable -eq "否") {
        return "暂不处理"
    }
    if ($sourceType -in @("manual", "official_page", "direct_url")) {
        return "人工确认"
    }
    if ($sourceType -eq "winget") {
        return "人工确认"
    }

    return "无法自动判断"
}

function Get-UpdateCheckResult {
    param(
        [object]$App,
        [object]$WingetInfo
    )

    $name = [string](Get-ConfigValue -Object $App -Name "name" -Default "未命名软件")
    $category = [string](Get-ConfigValue -Object $App -Name "category" -Default "")
    $risk = [string](Get-ConfigValue -Object $App -Name "riskLevel" -Default "")
    $sourceType = [string](Get-ConfigValue -Object $App -Name "officialSourceType" -Default "manual")
    $officialUrl = [string](Get-ConfigValue -Object $App -Name "officialUrl" -Default "")
    $allowDownload = Get-BoolConfig -Object $App -Name "allowAutoDownload" -Default $false
    $allowUpgrade = Get-BoolConfig -Object $App -Name "allowAutoUpgrade" -Default $false
    $notes = [string](Get-ConfigValue -Object $App -Name "notes" -Default "")

    Write-UpdateLog -Message "[检查] $name 更新状态，来源类型：$sourceType" -Level "INFO"
    $current = Get-CurrentInstalledVersionForUpdate -App $App

    $latest = [PSCustomObject]@{ LatestVersion = ""; UpdateState = "未知"; Note = "无法自动判断" }
    switch ($sourceType) {
        "winget" {
            $latest = Get-LatestVersionByWinget -App $App -WingetInfo $WingetInfo
        }
        "github_release" {
            $latest = Get-LatestVersionByGitHubRelease -App $App
        }
        "direct_url" {
            $latest = [PSCustomObject]@{ LatestVersion = ""; UpdateState = "未知"; Note = "direct_url 本阶段只记录来源，不下载，无法自动判断版本" }
            Write-UpdateLog -Message "[跳过] $name direct_url 本阶段不下载。" -Level "INFO"
        }
        "official_page" {
            $latest = [PSCustomObject]@{ LatestVersion = ""; UpdateState = "未知"; Note = "官方页面需人工确认，本阶段不爬取" }
            Write-UpdateLog -Message "[跳过] $name official_page 不做复杂爬取。" -Level "INFO"
        }
        default {
            $latest = [PSCustomObject]@{ LatestVersion = ""; UpdateState = "未知"; Note = "手动维护来源" }
            Write-UpdateLog -Message "[跳过] $name manual 来源，只检测当前版本。" -Level "INFO"
        }
    }

    $currentVersionText = if (-not [string]::IsNullOrWhiteSpace($current.Version)) { $current.Version } elseif ($current.Installed) { "未知" } else { "未安装" }
    $latestVersionText = if (-not [string]::IsNullOrWhiteSpace($latest.LatestVersion)) { $latest.LatestVersion } else { "未自动判断" }
    $updateAvailable = Compare-UpdateVersions -CurrentVersion $current.Version -LatestVersion $latest.LatestVersion -FallbackState $latest.UpdateState
    $suggestion = Get-UpdateSuggestion -App $App -UpdateAvailable $updateAvailable -LatestVersion $latest.LatestVersion

    return [PSCustomObject]@{
        Name = $name
        Category = $category
        RiskLevel = $risk
        CurrentVersion = $currentVersionText
        LatestVersion = $latestVersionText
        UpdateAvailable = $updateAvailable
        SourceType = $sourceType
        OfficialSource = $officialUrl
        AllowAutoDownload = if ($allowDownload) { "是" } else { "否" }
        AllowAutoUpgrade = if ($allowUpgrade) { "是" } else { "否" }
        Suggestion = $suggestion
        Note = ("{0}；{1}；{2}" -f $current.Source, $latest.Note, $notes)
    }
}

function Generate-UpdateCheckReport {
    param(
        [object[]]$Results,
        [object]$WingetInfo
    )

    $info = Get-SystemInfo
    $isAdminNow = Test-Admin
    $lines = New-Object System.Collections.Generic.List[string]

    $lines.Add("# 软件更新检查报告") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("运行时间：$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))") | Out-Null
    $lines.Add("电脑名称：$($info.ComputerName)") | Out-Null
    $lines.Add("当前用户：$($info.UserName)") | Out-Null
    $lines.Add("Windows 版本：$($info.WindowsVersion)") | Out-Null
    $lines.Add("是否管理员权限：$(if ($isAdminNow) { '是' } else { '否' })") | Out-Null
    $lines.Add("winget 是否可用：$(if ($WingetInfo.Available) { '是' } else { '否' }) $($WingetInfo.Version)") | Out-Null
    $lines.Add("更新日志路径：$Script:UpdateLogPath") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("## 更新检查结果") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("| 软件 | 分类 | 风险 | 当前版本 | 最新版本 | 是否可更新 | 来源 | 官方来源 | 允许自动下载 | 允许自动升级 | 建议动作 | 备注 |") | Out-Null
    $lines.Add("| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |") | Out-Null

    foreach ($result in $Results) {
        $lines.Add((
            "| {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7} | {8} | {9} | {10} | {11} |" -f
            (Escape-MarkdownCell $result.Name),
            (Escape-MarkdownCell $result.Category),
            (Escape-MarkdownCell $result.RiskLevel),
            (Escape-MarkdownCell $result.CurrentVersion),
            (Escape-MarkdownCell $result.LatestVersion),
            (Escape-MarkdownCell $result.UpdateAvailable),
            (Escape-MarkdownCell $result.SourceType),
            (Escape-MarkdownCell $result.OfficialSource),
            (Escape-MarkdownCell $result.AllowAutoDownload),
            (Escape-MarkdownCell $result.AllowAutoUpgrade),
            (Escape-MarkdownCell $result.Suggestion),
            (Escape-MarkdownCell $result.Note)
        )) | Out-Null
    }

    $lines.Add("") | Out-Null
    $lines.Add("## 说明") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("- v2.1 只做只读更新检查，不下载、不安装、不升级。") | Out-Null
    $lines.Add("- `未自动判断` 表示当前来源不适合自动解析，或本阶段按策略不爬取/不下载。") | Out-Null
    $lines.Add("- C 类或 high 风险软件默认只检测，不自动升级。") | Out-Null

    Set-Content -LiteralPath $Script:UpdateReportPath -Value $lines -Encoding UTF8
    Write-UpdateLog -Message "[报告] 已生成：$Script:UpdateReportPath" -Level "SUCCESS"
    return $Script:UpdateReportPath
}

function Run-UpdateCheckOnly {
    $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $Script:UpdateLogPath = Join-Path $Script:UpdateLogsDir ("update_check_{0}.log" -f $stamp)
    $Script:UpdateReportPath = Join-Path $Script:UpdateReportsDir ("update_check_{0}.md" -f $stamp)

    foreach ($dir in @($Script:UpdateReportsDir, $Script:UpdateLogsDir, $Script:SourcesDir, $Script:PoliciesDir)) {
        if (-not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
    }

    Write-UpdateLog -Message "[开始] 检查可更新软件（只读模式）" -Level "INFO"
    Write-UpdateLog -Message "[安全] v2.1 不下载、不安装、不升级、不覆盖 installers。" -Level "INFO"

    $updateConfig = Load-UpdateConfig
    $wingetInfo = Test-WingetAvailable
    $results = @()

    foreach ($app in @($updateConfig.apps | Where-Object { Get-BoolConfig -Object $_ -Name "enabled" -Default $true })) {
        try {
            $results += Get-UpdateCheckResult -App $app -WingetInfo $wingetInfo
        } catch {
            $name = [string](Get-ConfigValue -Object $app -Name "name" -Default "未命名软件")
            Write-UpdateLog -Message "[错误] $name 更新检查失败：$($_.Exception.Message)" -Level "ERROR"
            $results += [PSCustomObject]@{
                Name = $name
                Category = [string](Get-ConfigValue -Object $app -Name "category" -Default "")
                RiskLevel = [string](Get-ConfigValue -Object $app -Name "riskLevel" -Default "")
                CurrentVersion = "未知"
                LatestVersion = "未自动判断"
                UpdateAvailable = "未知"
                SourceType = [string](Get-ConfigValue -Object $app -Name "officialSourceType" -Default "")
                OfficialSource = [string](Get-ConfigValue -Object $app -Name "officialUrl" -Default "")
                AllowAutoDownload = "否"
                AllowAutoUpgrade = "否"
                Suggestion = "人工确认"
                Note = "检查异常：$($_.Exception.Message)"
            }
        }
    }

    Generate-UpdateCheckReport -Results $results -WingetInfo $wingetInfo | Out-Null

    Write-Host ""
    Write-Host "========================================="
    Write-Host "更新检查完成"
    Write-Host "========================================="
    Write-Host ""
    Write-Host "已检查：$($results.Count)"
    Write-Host "可能有更新：$(@($results | Where-Object { $_.UpdateAvailable -eq '是' }).Count)"
    Write-Host "无法自动判断：$(@($results | Where-Object { $_.UpdateAvailable -eq '未知' }).Count)"
    Write-Host ""
    Write-Host "更新报告路径："
    Write-Host $Script:UpdateReportPath
    Write-Host ""
    Write-Host "更新日志路径："
    Write-Host $Script:UpdateLogPath
    Write-Host ""
}

function Write-DownloadLog {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS", "DEBUG")][string]$Level = "INFO",
        [switch]$NoConsole
    )

    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[{0}] [{1}] {2}" -f $time, $Level, $Message

    if (-not [string]::IsNullOrWhiteSpace($Script:DownloadLogPath)) {
        try {
            Add-Content -LiteralPath $Script:DownloadLogPath -Value $line -Encoding UTF8
        } catch {
            Write-Host "[下载日志错误] 无法写入日志：$($_.Exception.Message)" -ForegroundColor Red
        }
    }

    if (-not $NoConsole) {
        switch ($Level) {
            "WARN"    { Write-Host $Message -ForegroundColor Yellow }
            "ERROR"   { Write-Host $Message -ForegroundColor Red }
            "SUCCESS" { Write-Host $Message -ForegroundColor Green }
            "DEBUG"   { Write-Host $Message -ForegroundColor DarkGray }
            default   { Write-Host $Message }
        }
    }
}

function New-DefaultAllowlistObject {
    return [PSCustomObject]@{
        allowedDomains = @(
            "python.org",
            "nodejs.org",
            "github.com",
            "api.github.com",
            "objects.githubusercontent.com",
            "githubusercontent.com",
            "tongyi.aliyun.com",
            "openai.com"
        )
        notes = "v2.2 下载白名单。确认后才允许下载；不在白名单内的 URL 一律禁止。"
    }
}

function Load-Allowlist {
    if (-not (Test-Path -LiteralPath $Script:AllowlistPath)) {
        Write-DownloadLog -Message "[白名单] allowlist.json 不存在，正在创建默认模板：$Script:AllowlistPath" -Level "WARN"
        $defaultAllowlist = New-DefaultAllowlistObject
        $defaultAllowlist | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $Script:AllowlistPath -Encoding UTF8
        return [PSCustomObject]@{
            IsReady = $false
            WasCreated = $true
            Path = $Script:AllowlistPath
            AllowedDomains = @($defaultAllowlist.allowedDomains)
            Message = "白名单文件刚创建，请人工确认后重新运行下载。"
        }
    }

    try {
        Write-DownloadLog -Message "[白名单] 读取 allowlist.json：$Script:AllowlistPath" -Level "INFO"
        $raw = Get-Content -LiteralPath $Script:AllowlistPath -Raw -Encoding UTF8
        $allowlist = $raw | ConvertFrom-Json
        $domains = ConvertTo-StringArray (Get-ConfigValue -Object $allowlist -Name "allowedDomains" -Default @())
        if ($domains.Count -eq 0) {
            return [PSCustomObject]@{
                IsReady = $false
                WasCreated = $false
                Path = $Script:AllowlistPath
                AllowedDomains = @()
                Message = "白名单为空，请先配置 allowedDomains。"
            }
        }

        return [PSCustomObject]@{
            IsReady = $true
            WasCreated = $false
            Path = $Script:AllowlistPath
            AllowedDomains = $domains
            Message = "白名单已加载"
        }
    } catch {
        return [PSCustomObject]@{
            IsReady = $false
            WasCreated = $false
            Path = $Script:AllowlistPath
            AllowedDomains = @()
            Message = "白名单格式错误：$($_.Exception.Message)"
        }
    }
}

function Test-UrlAllowed {
    param(
        [string]$Url,
        [object]$Allowlist
    )

    if ([string]::IsNullOrWhiteSpace($Url)) {
        return [PSCustomObject]@{ Allowed = $false; Host = ""; Message = "URL 为空" }
    }
    if ($null -eq $Allowlist -or -not $Allowlist.IsReady) {
        return [PSCustomObject]@{ Allowed = $false; Host = ""; Message = $Allowlist.Message }
    }

    try {
        $uri = [Uri]$Url
        if ($uri.Scheme -notin @("https", "http")) {
            return [PSCustomObject]@{ Allowed = $false; Host = $uri.Host; Message = "仅允许 http/https URL" }
        }

        $hostName = $uri.Host.ToLowerInvariant()
        foreach ($domain in @($Allowlist.AllowedDomains)) {
            $allowedDomain = ([string]$domain).Trim().ToLowerInvariant()
            if ([string]::IsNullOrWhiteSpace($allowedDomain)) {
                continue
            }
            if ($hostName -eq $allowedDomain -or $hostName.EndsWith("." + $allowedDomain)) {
                return [PSCustomObject]@{ Allowed = $true; Host = $hostName; Message = "白名单通过：$allowedDomain" }
            }
        }

        return [PSCustomObject]@{ Allowed = $false; Host = $hostName; Message = "域名不在白名单：$hostName" }
    } catch {
        return [PSCustomObject]@{ Allowed = $false; Host = ""; Message = "URL 格式错误：$($_.Exception.Message)" }
    }
}

function Initialize-DownloadDirectories {
    foreach ($dir in @($Script:DownloadsDir, $Script:DownloadsLatestDir, $Script:DownloadsArchiveDir, $Script:UpdateReportsDir, $Script:UpdateLogsDir, $Script:SourcesDir, $Script:PoliciesDir)) {
        if (-not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-DownloadLog -Message "[目录] 已创建：$dir" -Level "INFO"
        }
    }
}

function Get-DownloadTimeoutMinutes {
    param([object]$UpdateConfig)

    $value = Get-ConfigValue -Object $UpdateConfig.settings -Name "downloadTimeoutMinutes" -Default $null
    if ($null -eq $value) {
        try {
            $mainConfig = Load-Config
            $value = Get-ConfigValue -Object $mainConfig.settings -Name "downloadTimeoutMinutes" -Default $null
        } catch {
            $value = $null
        }
    }

    if ($null -eq $value) {
        return 20
    }

    try {
        $minutes = [int]$value
        if ($minutes -le 0) {
            return 20
        }
        return $minutes
    } catch {
        return 20
    }
}

function Format-DurationText {
    param([TimeSpan]$Duration)

    if ($null -eq $Duration) {
        return "-"
    }

    if ($Duration.TotalMinutes -ge 1) {
        return ("{0}分{1:D2}秒" -f [int][Math]::Floor($Duration.TotalMinutes), $Duration.Seconds)
    }

    return ("{0:N1}秒" -f $Duration.TotalSeconds)
}

function ConvertTo-SafeDirectoryName {
    param([string]$Name)

    $safe = [string]$Name
    foreach ($char in [System.IO.Path]::GetInvalidFileNameChars()) {
        $safe = $safe.Replace([string]$char, "_")
    }
    if ([string]::IsNullOrWhiteSpace($safe)) {
        return "unknown"
    }
    return $safe
}

function Archive-ExistingDownload {
    param(
        [string]$AppName,
        [string]$TargetPath,
        [string]$Stamp
    )

    if ([string]::IsNullOrWhiteSpace($TargetPath) -or -not (Test-Path -LiteralPath $TargetPath)) {
        return [PSCustomObject]@{ Archived = $false; ArchivePath = ""; Message = "没有同名旧文件" }
    }

    $safeName = ConvertTo-SafeDirectoryName -Name $AppName
    $archiveDir = Join-Path (Join-Path $Script:DownloadsArchiveDir $safeName) $Stamp
    New-Item -ItemType Directory -Path $archiveDir -Force | Out-Null
    $archivePath = Join-Path $archiveDir (Split-Path -Leaf $TargetPath)
    Move-Item -LiteralPath $TargetPath -Destination $archivePath -Force
    Write-DownloadLog -Message "[归档] $AppName 已归档旧文件：$archivePath" -Level "INFO"

    return [PSCustomObject]@{ Archived = $true; ArchivePath = $archivePath; Message = "旧文件已归档" }
}

function Get-GitHubLatestReleaseAsset {
    param(
        [object]$App,
        [object]$Allowlist
    )

    $name = [string](Get-ConfigValue -Object $App -Name "name" -Default "未命名软件")
    $repo = [string](Get-ConfigValue -Object $App -Name "githubRepo" -Default "")
    $installerFileName = [string](Get-ConfigValue -Object $App -Name "installerFileName" -Default "")

    if ([string]::IsNullOrWhiteSpace($repo)) {
        return [PSCustomObject]@{ Success = $false; Url = ""; Version = ""; FileName = ""; Message = "未配置 githubRepo" }
    }

    $apiUrl = "https://api.github.com/repos/$repo/releases/latest"
    $apiAllowed = Test-UrlAllowed -Url $apiUrl -Allowlist $Allowlist
    if (-not $apiAllowed.Allowed) {
        return [PSCustomObject]@{ Success = $false; Url = ""; Version = ""; FileName = ""; Message = "GitHub API 未通过白名单：$($apiAllowed.Message)" }
    }

    try {
        Write-DownloadLog -Message "[GitHub] 读取 latest release：$apiUrl" -Level "INFO"
        $release = Invoke-RestMethod -Uri $apiUrl -Headers @{ "User-Agent" = "AI-Environment-Download-Agent-v2.2" } -UseBasicParsing -TimeoutSec 30
    } catch {
        return [PSCustomObject]@{ Success = $false; Url = ""; Version = ""; FileName = ""; Message = "GitHub release 查询失败：$($_.Exception.Message)" }
    }

    $assets = @($release.assets)
    if ($assets.Count -eq 0) {
        return [PSCustomObject]@{ Success = $false; Url = ""; Version = [string]$release.tag_name; FileName = ""; Message = "GitHub release 没有 assets" }
    }

    $excludePattern = "(?i)(arm64|aarch64|mac|darwin|linux|dmg|zip|tar\.gz|tar|appimage)"
    $includePattern = "(?i)(win|windows|x64|setup|installer)"
    $candidates = @()

    foreach ($asset in $assets) {
        $assetName = [string]$asset.name
        $assetUrl = [string]$asset.browser_download_url
        $extension = [System.IO.Path]::GetExtension($assetName).ToLowerInvariant()
        if ($extension -notin @(".exe", ".msi")) {
            continue
        }
        if ($assetName -match $excludePattern) {
            continue
        }

        $score = 10
        if ($assetName -match $includePattern) { $score += 20 }
        if ($extension -eq ".msi") { $score += 2 }
        if ($extension -eq ".exe") { $score += 2 }
        if (-not [string]::IsNullOrWhiteSpace($installerFileName)) {
            if ($assetName -ieq $installerFileName) { $score += 100 }
            elseif ($assetName -like ("*" + [System.IO.Path]::GetFileNameWithoutExtension($installerFileName) + "*")) { $score += 40 }
        }

        $candidates += [PSCustomObject]@{
            Name = $assetName
            Url = $assetUrl
            Score = $score
            Size = $asset.size
        }
    }

    if ($candidates.Count -eq 0) {
        return [PSCustomObject]@{ Success = $false; Url = ""; Version = [string]$release.tag_name; FileName = ""; Message = "未找到 Windows x64 exe/msi asset" }
    }

    $sorted = @($candidates | Sort-Object Score -Descending)
    $top = $sorted[0]
    if ($sorted.Count -gt 1 -and $sorted[0].Score -eq $sorted[1].Score) {
        return [PSCustomObject]@{ Success = $false; Url = ""; Version = [string]$release.tag_name; FileName = ""; Message = "匹配到多个同分候选，请人工确认：$($sorted[0].Name), $($sorted[1].Name)" }
    }

    $downloadAllowed = Test-UrlAllowed -Url $top.Url -Allowlist $Allowlist
    if (-not $downloadAllowed.Allowed) {
        return [PSCustomObject]@{ Success = $false; Url = ""; Version = [string]$release.tag_name; FileName = $top.Name; Message = "下载 URL 未通过白名单：$($downloadAllowed.Message)" }
    }

    Write-DownloadLog -Message "[GitHub] $name 选择 asset：$($top.Name)" -Level "INFO"
    return [PSCustomObject]@{ Success = $true; Url = $top.Url; Version = [string]$release.tag_name; FileName = $top.Name; Size = [long]$top.Size; Message = "GitHub asset 已匹配" }
}

function Download-InstallerFile {
    param(
        [string]$Url,
        [string]$TargetPath,
        [long]$ExpectedSizeBytes = 0,
        [int]$TimeoutMinutes = 20
    )

    $tempPath = "$TargetPath.part"
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $cleanedPartial = $false
    $timedOut = $false

    if (Test-Path -LiteralPath $tempPath) {
        try {
            Remove-Item -LiteralPath $tempPath -Force -ErrorAction Stop
            $cleanedPartial = $true
            Write-DownloadLog -Message "[清理] 已删除旧临时文件：$tempPath" -Level "WARN"
        } catch {
            $stopwatch.Stop()
            return [PSCustomObject]@{
                Success = $false
                Message = "清理旧临时文件失败：$($_.Exception.Message)"
                TempPath = $tempPath
                UsedTempFile = "是"
                TimedOut = "否"
                CleanedPartial = "否"
                ExpectedSizeText = if ($ExpectedSizeBytes -gt 0) { ConvertTo-SizeText -Bytes $ExpectedSizeBytes } else { "未知" }
                ActualSizeText = "-"
                SizeMatched = "未知"
                DurationText = Format-DurationText -Duration $stopwatch.Elapsed
            }
        }
    }

    try {
        Write-DownloadLog -Message "[下载] 开始：$Url" -Level "INFO"
        Write-DownloadLog -Message "[下载] 目标：$TargetPath" -Level "INFO"
        Write-DownloadLog -Message "[下载] 临时文件：$tempPath" -Level "INFO"
        Write-DownloadLog -Message "[下载] 预期大小：$(if ($ExpectedSizeBytes -gt 0) { ConvertTo-SizeText -Bytes $ExpectedSizeBytes } else { '未知' })" -Level "INFO"
        Write-DownloadLog -Message "[下载] 超时限制：$TimeoutMinutes 分钟" -Level "INFO"

        $request = $null
        $response = $null
        $stream = $null
        $fileStream = $null
        try {
            try {
                [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
            } catch {}

            $request = [System.Net.HttpWebRequest]::Create($Url)
            $request.Method = "GET"
            $request.AllowAutoRedirect = $true
            $request.UserAgent = "AI-Environment-Download-Agent-v2.4.1"
            $request.Timeout = 30000
            $request.ReadWriteTimeout = 30000

            $response = $request.GetResponse()
            $stream = $response.GetResponseStream()
            $fileStream = [System.IO.File]::Open($tempPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
            $buffer = New-Object byte[] (1024 * 1024)
            $totalRead = 0L
            $lastProgressLog = [DateTime]::UtcNow

            while ($true) {
                if ($stopwatch.Elapsed.TotalMinutes -ge $TimeoutMinutes) {
                    $timedOut = $true
                    throw (New-Object System.TimeoutException("下载超时（${TimeoutMinutes} 分钟）"))
                }

                $read = $stream.Read($buffer, 0, $buffer.Length)
                if ($read -le 0) {
                    break
                }

                $fileStream.Write($buffer, 0, $read)
                $totalRead += [long]$read

                if (([DateTime]::UtcNow - $lastProgressLog).TotalSeconds -ge 30) {
                    Write-DownloadLog -Message "[下载] 已写入：$(ConvertTo-SizeText -Bytes $totalRead)" -Level "DEBUG" -NoConsole
                    $lastProgressLog = [DateTime]::UtcNow
                }

                if ($ExpectedSizeBytes -gt 0 -and $totalRead -ge $ExpectedSizeBytes) {
                    break
                }
            }
        } catch [System.TimeoutException] {
            if ($null -ne $fileStream) { $fileStream.Dispose(); $fileStream = $null }
            if ($null -ne $stream) { $stream.Dispose(); $stream = $null }
            if ($null -ne $response) { $response.Close(); $response = $null }
            if (Test-Path -LiteralPath $tempPath) {
                Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
                $cleanedPartial = $true
            }

            $stopwatch.Stop()
            Write-DownloadLog -Message "[下载] 超时：$TimeoutMinutes 分钟，已清理半包：$(if ($cleanedPartial) { '是' } else { '否' })" -Level "ERROR"
            return [PSCustomObject]@{
                Success = $false
                Message = $_.Exception.Message
                TempPath = $tempPath
                UsedTempFile = "是"
                TimedOut = "是"
                CleanedPartial = if ($cleanedPartial) { "是" } else { "否" }
                ExpectedSizeText = if ($ExpectedSizeBytes -gt 0) { ConvertTo-SizeText -Bytes $ExpectedSizeBytes } else { "未知" }
                ActualSizeText = "-"
                SizeMatched = "未知"
                DurationText = Format-DurationText -Duration $stopwatch.Elapsed
            }
        } catch {
            if ($null -ne $fileStream) { $fileStream.Dispose(); $fileStream = $null }
            if ($null -ne $stream) { $stream.Dispose(); $stream = $null }
            if ($null -ne $response) { $response.Close(); $response = $null }

            $actualSizeTextOnFailure = "-"
            if (Test-Path -LiteralPath $tempPath) {
                try {
                    $actualSizeTextOnFailure = ConvertTo-SizeText -Bytes ([long](Get-Item -LiteralPath $tempPath -ErrorAction Stop).Length)
                } catch {}
                Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
                $cleanedPartial = $true
            }

            $stopwatch.Stop()
            Write-DownloadLog -Message "[下载] 失败：$($_.Exception.Message)，实际大小：$actualSizeTextOnFailure，已清理半包：$(if ($cleanedPartial) { '是' } else { '否' })" -Level "ERROR"
            return [PSCustomObject]@{
                Success = $false
                Message = "下载失败：$($_.Exception.Message)"
                TempPath = $tempPath
                UsedTempFile = "是"
                TimedOut = "否"
                CleanedPartial = if ($cleanedPartial) { "是" } else { "否" }
                ExpectedSizeText = if ($ExpectedSizeBytes -gt 0) { ConvertTo-SizeText -Bytes $ExpectedSizeBytes } else { "未知" }
                ActualSizeText = $actualSizeTextOnFailure
                SizeMatched = "未知"
                DurationText = Format-DurationText -Duration $stopwatch.Elapsed
            }
        } finally {
            if ($null -ne $fileStream) { $fileStream.Dispose() }
            if ($null -ne $stream) { $stream.Dispose() }
            if ($null -ne $response) { $response.Close() }
        }

        if (-not (Test-Path -LiteralPath $tempPath)) {
            $stopwatch.Stop()
            Write-DownloadLog -Message "[下载] 失败：临时文件不存在" -Level "ERROR"
            return [PSCustomObject]@{
                Success = $false
                Message = "下载完成后未找到临时文件"
                TempPath = $tempPath
                UsedTempFile = "是"
                TimedOut = "否"
                CleanedPartial = if ($cleanedPartial) { "是" } else { "否" }
                ExpectedSizeText = if ($ExpectedSizeBytes -gt 0) { ConvertTo-SizeText -Bytes $ExpectedSizeBytes } else { "未知" }
                ActualSizeText = "-"
                SizeMatched = "未知"
                DurationText = Format-DurationText -Duration $stopwatch.Elapsed
            }
        }

        $tempItem = Get-Item -LiteralPath $tempPath -ErrorAction Stop
        $actualSize = [long]$tempItem.Length
        $expectedSizeText = if ($ExpectedSizeBytes -gt 0) { ConvertTo-SizeText -Bytes $ExpectedSizeBytes } else { "未知" }
        $actualSizeText = ConvertTo-SizeText -Bytes $actualSize
        Write-DownloadLog -Message "[下载] 实际大小：$actualSizeText" -Level "INFO"

        $expectedExtension = [System.IO.Path]::GetExtension($TargetPath).ToLowerInvariant()
        if ($actualSize -le 0) {
            Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
            $cleanedPartial = $true
            $stopwatch.Stop()
            Write-DownloadLog -Message "[校验] 临时文件大小为 0，已清理半包" -Level "ERROR"
            return [PSCustomObject]@{
                Success = $false
                Message = "临时文件大小为 0"
                TempPath = $tempPath
                UsedTempFile = "是"
                TimedOut = "否"
                CleanedPartial = "是"
                ExpectedSizeText = $expectedSizeText
                ActualSizeText = $actualSizeText
                SizeMatched = "否"
                DurationText = Format-DurationText -Duration $stopwatch.Elapsed
            }
        }
        if ($expectedExtension -notin @(".exe", ".msi")) {
            Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
            $cleanedPartial = $true
            $stopwatch.Stop()
            Write-DownloadLog -Message "[校验] 目标扩展名不符合：$expectedExtension，已清理半包" -Level "ERROR"
            return [PSCustomObject]@{
                Success = $false
                Message = "目标扩展名不符合：$expectedExtension"
                TempPath = $tempPath
                UsedTempFile = "是"
                TimedOut = "否"
                CleanedPartial = "是"
                ExpectedSizeText = $expectedSizeText
                ActualSizeText = $actualSizeText
                SizeMatched = "未知"
                DurationText = Format-DurationText -Duration $stopwatch.Elapsed
            }
        }

        $sizeMatched = "未知"
        if ($ExpectedSizeBytes -gt 0) {
            $sizeMatched = if ($actualSize -eq $ExpectedSizeBytes) { "是" } else { "否" }
            Write-DownloadLog -Message "[校验] 大小匹配：$sizeMatched（预期 $expectedSizeText，实际 $actualSizeText）" -Level "INFO"
            if ($actualSize -ne $ExpectedSizeBytes) {
                Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
                $cleanedPartial = $true
                $stopwatch.Stop()
                Write-DownloadLog -Message "[校验] 文件大小与来源元数据不一致，已清理半包" -Level "ERROR"
                return [PSCustomObject]@{
                    Success = $false
                    Message = "文件大小与来源元数据不一致，实际 $actualSizeText，期望 $expectedSizeText"
                    TempPath = $tempPath
                    UsedTempFile = "是"
                    TimedOut = "否"
                    CleanedPartial = "是"
                    ExpectedSizeText = $expectedSizeText
                    ActualSizeText = $actualSizeText
                    SizeMatched = "否"
                    DurationText = Format-DurationText -Duration $stopwatch.Elapsed
                }
            }
        } else {
            Write-DownloadLog -Message "[校验] 未提供预期大小，跳过严格大小比对" -Level "WARN"
        }

        Move-Item -LiteralPath $tempPath -Destination $TargetPath -Force -ErrorAction Stop
        $stopwatch.Stop()
        Write-DownloadLog -Message "[下载] 完成并重命名为正式文件：$TargetPath" -Level "SUCCESS"
        Write-DownloadLog -Message "[下载] 最终状态：成功，耗时：$(Format-DurationText -Duration $stopwatch.Elapsed)" -Level "SUCCESS"
        return [PSCustomObject]@{
            Success = $true
            Message = "下载成功"
            TempPath = $tempPath
            UsedTempFile = "是"
            TimedOut = "否"
            CleanedPartial = if ($cleanedPartial) { "是" } else { "否" }
            ExpectedSizeText = $expectedSizeText
            ActualSizeText = $actualSizeText
            SizeMatched = $sizeMatched
            DurationText = Format-DurationText -Duration $stopwatch.Elapsed
        }
    } catch {
        if (Test-Path -LiteralPath $tempPath) {
            Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
            $cleanedPartial = $true
        }
        $stopwatch.Stop()
        Write-DownloadLog -Message "[下载] 异常：$($_.Exception.Message)，已清理半包：$(if ($cleanedPartial) { '是' } else { '否' })" -Level "ERROR"
        return [PSCustomObject]@{
            Success = $false
            Message = "下载失败：$($_.Exception.Message)"
            TempPath = $tempPath
            UsedTempFile = "是"
            TimedOut = if ($timedOut) { "是" } else { "否" }
            CleanedPartial = if ($cleanedPartial) { "是" } else { "否" }
            ExpectedSizeText = if ($ExpectedSizeBytes -gt 0) { ConvertTo-SizeText -Bytes $ExpectedSizeBytes } else { "未知" }
            ActualSizeText = "-"
            SizeMatched = "未知"
            DurationText = Format-DurationText -Duration $stopwatch.Elapsed
        }
    }
}

function Get-FileSignatureInfo {
    param([string]$Path)

    try {
        $signature = Get-AuthenticodeSignature -LiteralPath $Path -ErrorAction Stop
        $signer = ""
        if ($null -ne $signature.SignerCertificate) {
            $signer = [string]$signature.SignerCertificate.Subject
        }

        return [PSCustomObject]@{
            Status = [string]$signature.Status
            Signer = $signer
            IsValid = ($signature.Status -eq "Valid")
            Note = [string]$signature.StatusMessage
        }
    } catch {
        return [PSCustomObject]@{
            Status = "未知"
            Signer = ""
            IsValid = $false
            Note = "签名读取失败：$($_.Exception.Message)"
        }
    }
}

function Test-DownloadedFile {
    param(
        [string]$Path,
        [string]$ExpectedFileName,
        [long]$ExpectedSizeBytes = 0
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return [PSCustomObject]@{ Success = $false; FileSizeText = "-"; FileSizeBytes = 0; SignatureStatus = "-"; Signer = "-"; Note = "文件不存在" }
    }

    $item = Get-Item -LiteralPath $Path -ErrorAction Stop
    if ($item.Length -le 0) {
        return [PSCustomObject]@{ Success = $false; FileSizeText = "0 B"; FileSizeBytes = 0; SignatureStatus = "-"; Signer = "-"; Note = "文件大小为 0" }
    }

    $extension = [System.IO.Path]::GetExtension($item.Name).ToLowerInvariant()
    if ($extension -notin @(".exe", ".msi")) {
        return [PSCustomObject]@{ Success = $false; FileSizeText = (ConvertTo-SizeText -Bytes $item.Length); FileSizeBytes = $item.Length; SignatureStatus = "-"; Signer = "-"; Note = "文件扩展名不符合：$extension" }
    }

    if ($ExpectedSizeBytes -gt 0 -and $item.Length -ne $ExpectedSizeBytes) {
        $actualText = ConvertTo-SizeText -Bytes $item.Length
        $expectedText = ConvertTo-SizeText -Bytes $ExpectedSizeBytes
        Write-DownloadLog -Message "[校验] $ExpectedFileName 文件大小不一致：实际 $actualText，期望 $expectedText" -Level "ERROR"
        return [PSCustomObject]@{
            Success = $false
            FileSizeText = $actualText
            FileSizeBytes = $item.Length
            SignatureStatus = "-"
            Signer = "-"
            Note = "文件大小与来源元数据不一致，实际 $actualText，期望 $expectedText"
        }
    }

    $signature = Get-FileSignatureInfo -Path $Path
    Write-DownloadLog -Message "[校验] $ExpectedFileName 大小：$(ConvertTo-SizeText -Bytes $item.Length)，签名：$($signature.Status)" -Level "INFO"

    return [PSCustomObject]@{
        Success = $true
        FileSizeText = ConvertTo-SizeText -Bytes $item.Length
        FileSizeBytes = $item.Length
        SignatureStatus = $signature.Status
        Signer = if ([string]::IsNullOrWhiteSpace($signature.Signer)) { "-" } else { $signature.Signer }
        Note = $signature.Note
    }
}

function New-DownloadResult {
    param(
        [object]$App,
        [string]$SourceUrl = "",
        [string]$Whitelist = "-",
        [string]$Status = "跳过",
        [string]$FileSize = "-",
        [string]$SignatureStatus = "-",
        [string]$Signer = "-",
        [string]$UsedTempFile = "-",
        [string]$SizeMatched = "-",
        [string]$CleanedPartial = "-",
        [string]$Duration = "-",
        [string]$Note = ""
    )

    $allowDownload = Get-BoolConfig -Object $App -Name "allowAutoDownload" -Default $false
    return [PSCustomObject]@{
        Name = [string](Get-ConfigValue -Object $App -Name "name" -Default "未命名软件")
        Category = [string](Get-ConfigValue -Object $App -Name "category" -Default "")
        SourceType = [string](Get-ConfigValue -Object $App -Name "officialSourceType" -Default "")
        SourceUrl = $SourceUrl
        AllowDownload = if ($allowDownload) { "是" } else { "否" }
        Whitelist = $Whitelist
        InstallerFileName = [string](Get-ConfigValue -Object $App -Name "installerFileName" -Default "")
        Status = $Status
        FileSize = $FileSize
        SignatureStatus = $SignatureStatus
        Signer = $Signer
        UsedTempFile = $UsedTempFile
        SizeMatched = $SizeMatched
        CleanedPartial = $CleanedPartial
        Duration = $Duration
        Note = $Note
    }
}

function Get-DownloadCheckResult {
    param(
        [object]$App,
        [object]$Allowlist,
        [string]$Stamp,
        [int]$DownloadTimeoutMinutes = 20
    )

    $name = [string](Get-ConfigValue -Object $App -Name "name" -Default "未命名软件")
    $sourceType = [string](Get-ConfigValue -Object $App -Name "officialSourceType" -Default "")
    $installerFileName = [string](Get-ConfigValue -Object $App -Name "installerFileName" -Default "")
    $allowDownload = Get-BoolConfig -Object $App -Name "allowAutoDownload" -Default $false

    Write-DownloadLog -Message "[检查] $name 下载资格，来源：$sourceType，允许下载：$allowDownload" -Level "INFO"

    if (-not (Get-BoolConfig -Object $App -Name "enabled" -Default $true)) {
        return New-DownloadResult -App $App -Status "跳过" -Note "未启用"
    }
    if (-not $allowDownload) {
        return New-DownloadResult -App $App -Status "跳过" -Note "allowAutoDownload=false"
    }
    if ($sourceType -notin @("direct_url", "github_release")) {
        return New-DownloadResult -App $App -Status "跳过" -Note "v2.2 暂不支持 $sourceType 下载"
    }
    if ([string]::IsNullOrWhiteSpace($installerFileName)) {
        return New-DownloadResult -App $App -Status "失败" -Note "installerFileName 未配置"
    }
    if (-not $Allowlist.IsReady) {
        return New-DownloadResult -App $App -Status "跳过" -Whitelist "未确认" -Note $Allowlist.Message
    }

    $sourceUrl = ""
    $expectedSizeBytes = 0
    if ($sourceType -eq "direct_url") {
        $sourceUrl = [string](Get-ConfigValue -Object $App -Name "directDownloadUrl" -Default "")
        $urlCheck = Test-UrlAllowed -Url $sourceUrl -Allowlist $Allowlist
        Write-DownloadLog -Message "[白名单] $name direct_url 校验：$($urlCheck.Message)" -Level "INFO"
        if (-not $urlCheck.Allowed) {
            return New-DownloadResult -App $App -SourceUrl $sourceUrl -Status "失败" -Whitelist "未通过" -Note $urlCheck.Message
        }
    } elseif ($sourceType -eq "github_release") {
        $assetResult = Get-GitHubLatestReleaseAsset -App $App -Allowlist $Allowlist
        if (-not $assetResult.Success) {
            return New-DownloadResult -App $App -Status "失败" -Whitelist "未通过" -Note $assetResult.Message
        }
        $sourceUrl = $assetResult.Url
        $expectedSizeBytes = [long]$assetResult.Size
        $urlCheck = Test-UrlAllowed -Url $sourceUrl -Allowlist $Allowlist
        Write-DownloadLog -Message "[白名单] $name GitHub asset 校验：$($urlCheck.Message)" -Level "INFO"
        if (-not $urlCheck.Allowed) {
            return New-DownloadResult -App $App -SourceUrl $sourceUrl -Status "失败" -Whitelist "未通过" -Note $urlCheck.Message
        }
    }

    if ([string]::IsNullOrWhiteSpace($sourceUrl)) {
        return New-DownloadResult -App $App -Status "失败" -Whitelist "未通过" -Note "下载 URL 为空"
    }

    $safeName = ConvertTo-SafeDirectoryName -Name $name
    $targetDir = Join-Path $Script:DownloadsLatestDir $safeName
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    $targetPath = Join-Path $targetDir $installerFileName

    $archiveResult = Archive-ExistingDownload -AppName $name -TargetPath $targetPath -Stamp $Stamp

    $download = Download-InstallerFile -Url $sourceUrl -TargetPath $targetPath -ExpectedSizeBytes $expectedSizeBytes -TimeoutMinutes $DownloadTimeoutMinutes
    if (-not $download.Success) {
        $restoreNote = ""
        if ($archiveResult.Archived -and -not (Test-Path -LiteralPath $targetPath) -and (Test-Path -LiteralPath $archiveResult.ArchivePath)) {
            try {
                Copy-Item -LiteralPath $archiveResult.ArchivePath -Destination $targetPath -Force -ErrorAction Stop
                $restoreNote = "；已从归档恢复旧 latest 文件"
                Write-DownloadLog -Message "[恢复] 下载失败，已恢复旧 latest 文件：$targetPath" -Level "WARN"
            } catch {
                $restoreNote = "；恢复旧 latest 文件失败：$($_.Exception.Message)"
                Write-DownloadLog -Message "[恢复] 恢复旧 latest 文件失败：$($_.Exception.Message)" -Level "ERROR"
            }
        }
        Write-DownloadLog -Message "[下载] 最终状态：失败，$($download.Message)$restoreNote" -Level "ERROR"
        return New-DownloadResult -App $App -SourceUrl $sourceUrl -Status "失败" -Whitelist "通过" -UsedTempFile $download.UsedTempFile -SizeMatched $download.SizeMatched -CleanedPartial $download.CleanedPartial -Duration $download.DurationText -Note ($download.Message + $restoreNote)
    }

    $validation = Test-DownloadedFile -Path $targetPath -ExpectedFileName $installerFileName -ExpectedSizeBytes $expectedSizeBytes
    if (-not $validation.Success) {
        Write-DownloadLog -Message "[下载] 最终状态：失败，正式文件校验失败：$($validation.Note)" -Level "ERROR"
        return New-DownloadResult -App $App -SourceUrl $sourceUrl -Status "失败" -Whitelist "通过" -FileSize $validation.FileSizeText -SignatureStatus $validation.SignatureStatus -Signer $validation.Signer -UsedTempFile $download.UsedTempFile -SizeMatched $download.SizeMatched -CleanedPartial $download.CleanedPartial -Duration $download.DurationText -Note $validation.Note
    }

    return New-DownloadResult -App $App -SourceUrl $sourceUrl -Status "成功" -Whitelist "通过" -FileSize $validation.FileSizeText -SignatureStatus $validation.SignatureStatus -Signer $validation.Signer -UsedTempFile $download.UsedTempFile -SizeMatched $download.SizeMatched -CleanedPartial $download.CleanedPartial -Duration $download.DurationText -Note ("已下载到 " + $targetPath)
}

function Generate-DownloadReport {
    param(
        [object[]]$Results,
        [object]$Allowlist
    )

    $info = Get-SystemInfo
    $isAdminNow = Test-Admin
    $lines = New-Object System.Collections.Generic.List[string]

    $lines.Add("# 最新安装包下载报告") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("运行时间：$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))") | Out-Null
    $lines.Add("电脑名称：$($info.ComputerName)") | Out-Null
    $lines.Add("当前用户：$($info.UserName)") | Out-Null
    $lines.Add("Windows 版本：$($info.WindowsVersion)") | Out-Null
    $lines.Add("是否管理员权限：$(if ($isAdminNow) { '是' } else { '否' })") | Out-Null
    $lines.Add("白名单路径：$Script:AllowlistPath") | Out-Null
    $lines.Add("白名单状态：$($Allowlist.Message)") | Out-Null
    $lines.Add("下载目录：$Script:DownloadsLatestDir") | Out-Null
    $lines.Add("下载日志路径：$Script:DownloadLogPath") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("## 下载结果") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("| 软件 | 分类 | 来源类型 | 来源地址 | 允许下载 | 白名单 | 下载状态 | 文件名 | 文件大小 | 签名 | 签名者 | 使用临时文件 | 大小匹配 | 清理半包 | 下载耗时 | 备注 |") | Out-Null
    $lines.Add("| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |") | Out-Null

    foreach ($result in $Results) {
        $lines.Add((
            "| {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7} | {8} | {9} | {10} | {11} | {12} | {13} | {14} | {15} |" -f
            (Escape-MarkdownCell $result.Name),
            (Escape-MarkdownCell $result.Category),
            (Escape-MarkdownCell $result.SourceType),
            (Escape-MarkdownCell $result.SourceUrl),
            (Escape-MarkdownCell $result.AllowDownload),
            (Escape-MarkdownCell $result.Whitelist),
            (Escape-MarkdownCell $result.Status),
            (Escape-MarkdownCell $result.InstallerFileName),
            (Escape-MarkdownCell $result.FileSize),
            (Escape-MarkdownCell $result.SignatureStatus),
            (Escape-MarkdownCell $result.Signer),
            (Escape-MarkdownCell $result.UsedTempFile),
            (Escape-MarkdownCell $result.SizeMatched),
            (Escape-MarkdownCell $result.CleanedPartial),
            (Escape-MarkdownCell $result.Duration),
            (Escape-MarkdownCell $result.Note)
        )) | Out-Null
    }

    $lines.Add("") | Out-Null
    $lines.Add("## 安全说明") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("- v2.4.1 只下载，不安装、不升级、不复制到 installers。") | Out-Null
    $lines.Add("- 下载先写入 .part 临时文件，校验通过后才重命名为正式文件。") | Out-Null
    $lines.Add("- 下载文件只会放在 downloads/latest；旧正式文件会先归档到 downloads/archive。") | Out-Null
    $lines.Add("- 请人工确认安装包来源和数字签名后，再决定是否用于后续流程。") | Out-Null

    Set-Content -LiteralPath $Script:DownloadReportPath -Value $lines -Encoding UTF8
    Write-DownloadLog -Message "[报告] 已生成：$Script:DownloadReportPath" -Level "SUCCESS"
}

function Run-DownloadLatestInstallers {
    $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $Script:DownloadLogPath = Join-Path $Script:UpdateLogsDir ("download_{0}.log" -f $stamp)
    $Script:DownloadReportPath = Join-Path $Script:UpdateReportsDir ("download_report_{0}.md" -f $stamp)

    Initialize-DownloadDirectories
    Write-DownloadLog -Message "[开始] 下载最新版安装包（隔离目录，只下载不安装）" -Level "INFO"
    Write-DownloadLog -Message "[安全] 不安装、不升级、不覆盖 installers、不复制安装包。" -Level "INFO"

    $updateConfig = Load-UpdateConfig
    $downloadTimeoutMinutes = Get-DownloadTimeoutMinutes -UpdateConfig $updateConfig
    Write-DownloadLog -Message "[配置] 下载超时：$downloadTimeoutMinutes 分钟" -Level "INFO"
    $allowlist = Load-Allowlist
    if (-not $allowlist.IsReady) {
        Write-DownloadLog -Message "[白名单] $($allowlist.Message)" -Level "WARN"
    }

    $results = @()
    foreach ($app in @($updateConfig.apps)) {
        try {
            $results += Get-DownloadCheckResult -App $app -Allowlist $allowlist -Stamp $stamp -DownloadTimeoutMinutes $downloadTimeoutMinutes
        } catch {
            $name = [string](Get-ConfigValue -Object $app -Name "name" -Default "未命名软件")
            Write-DownloadLog -Message "[错误] $name 下载处理失败：$($_.Exception.Message)" -Level "ERROR"
            $results += New-DownloadResult -App $app -Status "失败" -Note "异常：$($_.Exception.Message)"
        }
    }

    Generate-DownloadReport -Results $results -Allowlist $allowlist

    Write-Host ""
    Write-Host "========================================="
    Write-Host "下载检查完成"
    Write-Host "========================================="
    Write-Host ""
    Write-Host "成功：$(@($results | Where-Object { $_.Status -eq '成功' }).Count)"
    Write-Host "跳过：$(@($results | Where-Object { $_.Status -eq '跳过' }).Count)"
    Write-Host "失败：$(@($results | Where-Object { $_.Status -eq '失败' }).Count)"
    Write-Host ""
    Write-Host "下载报告路径："
    Write-Host $Script:DownloadReportPath
    Write-Host ""
    Write-Host "下载日志路径："
    Write-Host $Script:DownloadLogPath
    Write-Host ""
}

function Write-ConfigOperationLog {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS", "DEBUG")][string]$Level = "INFO",
        [string]$LogPath = ""
    )

    $targetLog = $LogPath
    if ([string]::IsNullOrWhiteSpace($targetLog)) {
        if (-not [string]::IsNullOrWhiteSpace($Script:ConfigRestoreLogPath)) {
            $targetLog = $Script:ConfigRestoreLogPath
        } else {
            $targetLog = $Script:ConfigBackupLogPath
        }
    }

    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[{0}] [{1}] {2}" -f $time, $Level, $Message

    if (-not [string]::IsNullOrWhiteSpace($targetLog)) {
        try {
            Add-Content -LiteralPath $targetLog -Value $line -Encoding UTF8
        } catch {
            Write-Host "[日志错误] 无法写入配置备份/恢复日志：$($_.Exception.Message)" -ForegroundColor Red
        }
    }

    switch ($Level) {
        "WARN"    { Write-Host $Message -ForegroundColor Yellow }
        "ERROR"   { Write-Host $Message -ForegroundColor Red }
        "SUCCESS" { Write-Host $Message -ForegroundColor Green }
        "DEBUG"   { Write-Host $Message -ForegroundColor DarkGray }
        default   { Write-Host $Message }
    }
}

function Initialize-BackupDirectories {
    param([string]$LogPath = "")

    foreach ($dir in @($Script:BackupsDir, $Script:ConfigBackupsDir, $Script:UpdateReportsDir, $Script:UpdateLogsDir)) {
        if (-not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-ConfigOperationLog -Message "[目录] 已创建：$dir" -Level "INFO" -LogPath $LogPath
        }
    }
}

function Get-ConfiguredBackupApps {
    param([object]$UpdateConfig)

    $apps = @()
    foreach ($app in @($UpdateConfig.apps)) {
        $name = [string](Get-ConfigValue -Object $app -Name "name" -Default "")
        if ($name -ne "OpenClaw") {
            continue
        }
        if (-not (Get-BoolConfig -Object $app -Name "enabled" -Default $true)) {
            continue
        }
        $configPaths = ConvertTo-StringArray (Get-ConfigValue -Object $app -Name "configPaths" -Default @())
        if ($configPaths.Count -eq 0) {
            continue
        }
        $apps += $app
    }

    return @($apps)
}

function Expand-ConfigPath {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return ""
    }

    return [Environment]::ExpandEnvironmentVariables($Path)
}

function Test-BackupSourcePath {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return [PSCustomObject]@{ Exists = $false; FullPath = ""; IsDirectory = $false; Message = "路径为空" }
    }

    try {
        if (-not (Test-Path -LiteralPath $Path)) {
            return [PSCustomObject]@{ Exists = $false; FullPath = $Path; IsDirectory = $false; Message = "未发现" }
        }

        $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
        return [PSCustomObject]@{ Exists = $true; FullPath = $item.FullName; IsDirectory = [bool]$item.PSIsContainer; Message = "已发现" }
    } catch {
        return [PSCustomObject]@{ Exists = $false; FullPath = $Path; IsDirectory = $false; Message = "检查失败：$($_.Exception.Message)" }
    }
}

function Test-PathExcluded {
    param(
        [string]$RelativePath,
        [string[]]$ExcludePatterns
    )

    if ([string]::IsNullOrWhiteSpace($RelativePath) -or $null -eq $ExcludePatterns -or $ExcludePatterns.Count -eq 0) {
        return $false
    }

    $normalized = $RelativePath.Replace("/", "\").TrimStart("\")
    $segments = @($normalized -split "\\")
    $leaf = Split-Path -Leaf $normalized

    foreach ($pattern in $ExcludePatterns) {
        $p = ([string]$pattern).Trim()
        if ([string]::IsNullOrWhiteSpace($p)) {
            continue
        }

        if ($leaf -like $p -or $normalized -like $p) {
            return $true
        }

        foreach ($segment in $segments) {
            if ($segment -like $p) {
                return $true
            }
        }

        if ($normalized -like ("*\" + $p) -or $normalized -like ($p + "\*") -or $normalized -like ("*\" + $p + "\*")) {
            return $true
        }
    }

    return $false
}

function Get-FileHashSafe {
    param([string]$Path)

    try {
        return (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash
    } catch {
        return "unknown"
    }
}

function Copy-ConfigDirectorySafely {
    param(
        [string]$SourcePath,
        [string]$BackupRoot,
        [string]$BackupSubdir,
        [string[]]$ExcludePatterns,
        [string]$LogPath = ""
    )

    $copiedFiles = @()
    $skippedFiles = @()
    $failedFiles = @()
    $totalBytes = 0L

    try {
        $item = Get-Item -LiteralPath $SourcePath -Force -ErrorAction Stop
        $sourceRoot = if ($item.PSIsContainer) { $item.FullName.TrimEnd("\") } else { (Split-Path -Parent $item.FullName).TrimEnd("\") }
        $files = @()

        if ($item.PSIsContainer) {
            $enumErrors = @()
            $files = @(Get-ChildItem -LiteralPath $item.FullName -File -Recurse -Force -ErrorAction SilentlyContinue -ErrorVariable enumErrors)
            foreach ($enumError in @($enumErrors)) {
                $failedFiles += [PSCustomObject]@{
                    SourcePath = $item.FullName
                    RelativePath = "-"
                    Reason = "枚举失败：$($enumError.Exception.Message)"
                }
                Write-ConfigOperationLog -Message "[失败] 枚举失败：$($enumError.Exception.Message)" -Level "ERROR" -LogPath $LogPath
            }
        } else {
            $files = @($item)
        }

        foreach ($file in $files) {
            $relativePath = if ($item.PSIsContainer) {
                $file.FullName.Substring($sourceRoot.Length).TrimStart("\")
            } else {
                $file.Name
            }

            if (Test-PathExcluded -RelativePath $relativePath -ExcludePatterns $ExcludePatterns) {
                $skippedFiles += [PSCustomObject]@{
                    SourcePath = $file.FullName
                    RelativePath = $relativePath
                    Reason = "匹配排除规则"
                }
                Write-ConfigOperationLog -Message "[跳过] $($file.FullName)（匹配排除规则）" -Level "DEBUG" -LogPath $LogPath
                continue
            }

            $backupRelativePath = Join-Path $BackupSubdir $relativePath
            $destinationPath = Join-Path $BackupRoot $backupRelativePath
            $destinationDir = Split-Path -Parent $destinationPath

            try {
                if (-not (Test-Path -LiteralPath $destinationDir)) {
                    New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
                }

                Copy-Item -LiteralPath $file.FullName -Destination $destinationPath -Force -ErrorAction Stop
                $hash = Get-FileHashSafe -Path $destinationPath
                $totalBytes += [long]$file.Length
                $copiedFiles += [PSCustomObject]@{
                    sourcePath = $sourceRoot
                    originalFullPath = $file.FullName
                    relativePath = $relativePath
                    backupRelativePath = $backupRelativePath
                    size = [long]$file.Length
                    lastWriteTime = $file.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
                    sha256 = $hash
                }
                Write-ConfigOperationLog -Message "[复制] $($file.FullName) -> $destinationPath" -Level "DEBUG" -LogPath $LogPath
            } catch {
                $failedFiles += [PSCustomObject]@{
                    SourcePath = $file.FullName
                    RelativePath = $relativePath
                    Reason = $_.Exception.Message
                }
                Write-ConfigOperationLog -Message "[失败] 复制失败：$($file.FullName)，原因：$($_.Exception.Message)" -Level "ERROR" -LogPath $LogPath
            }
        }
    } catch {
        $failedFiles += [PSCustomObject]@{
            SourcePath = $SourcePath
            RelativePath = "-"
            Reason = $_.Exception.Message
        }
        Write-ConfigOperationLog -Message "[失败] 备份源处理失败：$SourcePath，原因：$($_.Exception.Message)" -Level "ERROR" -LogPath $LogPath
    }

    return [PSCustomObject]@{
        CopiedFiles = @($copiedFiles)
        SkippedFiles = @($skippedFiles)
        FailedFiles = @($failedFiles)
        TotalBytes = $totalBytes
    }
}

function New-BackupManifest {
    param(
        [string]$AppName,
        [string]$BackupRoot,
        [object[]]$SourcePaths,
        [object[]]$FileList,
        [object[]]$SkippedFiles,
        [object[]]$FailedFiles,
        [string[]]$ExcludePatterns,
        [string]$LogPath = ""
    )

    $manifestPath = Join-Path $BackupRoot "manifest.json"
    $manifest = [PSCustomObject]@{
        appName = $AppName
        backupTime = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        computerName = $env:COMPUTERNAME
        userName = [Environment]::UserName
        sourcePaths = @($SourcePaths)
        backupRoot = $BackupRoot
        totalFiles = @($FileList).Count
        totalBytes = [long](@($FileList) | Measure-Object -Property size -Sum).Sum
        skippedFiles = @($SkippedFiles).Count
        failedFiles = @($FailedFiles).Count
        excludePatterns = @($ExcludePatterns)
        fileList = @($FileList)
        skippedFileList = @($SkippedFiles)
        failedFileList = @($FailedFiles)
    }

    try {
        $manifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
        Write-ConfigOperationLog -Message "[manifest] 已生成：$manifestPath" -Level "SUCCESS" -LogPath $LogPath
    } catch {
        Write-ConfigOperationLog -Message "[manifest] 生成失败：$($_.Exception.Message)" -Level "ERROR" -LogPath $LogPath
        throw
    }

    return $manifestPath
}

function Invoke-ConfigBackupForApp {
    param(
        [object]$App,
        [string]$BackupRoot,
        [string]$LogPath = ""
    )

    $appName = [string](Get-ConfigValue -Object $App -Name "name" -Default "未命名软件")
    $configPaths = ConvertTo-StringArray (Get-ConfigValue -Object $App -Name "configPaths" -Default @())
    $excludePatterns = ConvertTo-StringArray (Get-ConfigValue -Object $App -Name "excludePatterns" -Default @())

    New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null
    Write-ConfigOperationLog -Message "[备份] 软件：$appName" -Level "INFO" -LogPath $LogPath
    Write-ConfigOperationLog -Message "[备份] 目标：$BackupRoot" -Level "INFO" -LogPath $LogPath

    $sourceResults = @()
    $fileList = @()
    $skippedFiles = @()
    $failedFiles = @()
    $index = 1

    foreach ($rawPath in $configPaths) {
        $expandedPath = Expand-ConfigPath -Path $rawPath
        $sourceCheck = Test-BackupSourcePath -Path $expandedPath

        $sourceResult = [PSCustomObject]@{
            configuredPath = [string]$rawPath
            expandedPath = $expandedPath
            exists = [bool]$sourceCheck.Exists
            isDirectory = [bool]$sourceCheck.IsDirectory
            backupSubdir = ""
            status = $sourceCheck.Message
        }

        if (-not $sourceCheck.Exists) {
            Write-ConfigOperationLog -Message "[路径] 未发现：$expandedPath" -Level "WARN" -LogPath $LogPath
            $sourceResults += $sourceResult
            continue
        }

        $leaf = Split-Path -Leaf $sourceCheck.FullPath
        if ([string]::IsNullOrWhiteSpace($leaf)) {
            $leaf = "config"
        }
        $backupSubdir = "source_{0:D2}_{1}" -f $index, (ConvertTo-SafeDirectoryName -Name $leaf)
        $sourceResult.backupSubdir = $backupSubdir
        $sourceResult.status = "已备份"

        Write-ConfigOperationLog -Message "[路径] 已发现：$($sourceCheck.FullPath)" -Level "SUCCESS" -LogPath $LogPath
        Write-ConfigOperationLog -Message "[复制] 开始复制：$($sourceCheck.FullPath)" -Level "INFO" -LogPath $LogPath

        $copyResult = Copy-ConfigDirectorySafely -SourcePath $sourceCheck.FullPath -BackupRoot $BackupRoot -BackupSubdir $backupSubdir -ExcludePatterns $excludePatterns -LogPath $LogPath
        $fileList += @($copyResult.CopiedFiles)
        $skippedFiles += @($copyResult.SkippedFiles)
        $failedFiles += @($copyResult.FailedFiles)
        $sourceResults += $sourceResult
        $index++
    }

    $manifestPath = New-BackupManifest -AppName $appName -BackupRoot $BackupRoot -SourcePaths $sourceResults -FileList $fileList -SkippedFiles $skippedFiles -FailedFiles $failedFiles -ExcludePatterns $excludePatterns -LogPath $LogPath

    return [PSCustomObject]@{
        Success = (Test-Path -LiteralPath $manifestPath)
        AppName = $appName
        BackupRoot = $BackupRoot
        ManifestPath = $manifestPath
        SourcePaths = @($sourceResults)
        TotalFiles = @($fileList).Count
        TotalBytes = [long](@($fileList) | Measure-Object -Property size -Sum).Sum
        SkippedFiles = @($skippedFiles).Count
        FailedFiles = @($failedFiles).Count
        ExcludePatterns = @($excludePatterns)
        Note = if (@($sourceResults | Where-Object { $_.exists }).Count -gt 0) { "备份完成" } else { "未发现可备份配置路径" }
    }
}

function Generate-ConfigBackupReport {
    param([object]$Result)

    $info = Get-SystemInfo
    $isAdminNow = Test-Admin
    $lines = New-Object System.Collections.Generic.List[string]

    $lines.Add("# 软件配置备份报告") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("运行时间：$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))") | Out-Null
    $lines.Add("电脑名称：$($info.ComputerName)") | Out-Null
    $lines.Add("当前用户：$($info.UserName)") | Out-Null
    $lines.Add("是否管理员权限：$(if ($isAdminNow) { '是' } else { '否' })") | Out-Null
    $lines.Add("软件名称：$($Result.AppName)") | Out-Null
    $lines.Add("备份目标路径：$($Result.BackupRoot)") | Out-Null
    $lines.Add("成功文件数：$($Result.TotalFiles)") | Out-Null
    $lines.Add("失败文件数：$($Result.FailedFiles)") | Out-Null
    $lines.Add("跳过文件数：$($Result.SkippedFiles)") | Out-Null
    $lines.Add("总大小：$(ConvertTo-SizeText -Bytes $Result.TotalBytes)") | Out-Null
    $lines.Add("排除规则：$((@($Result.ExcludePatterns) -join '；'))") | Out-Null
    $lines.Add("manifest 路径：$($Result.ManifestPath)") | Out-Null
    $lines.Add("备份日志路径：$Script:ConfigBackupLogPath") | Out-Null
    $lines.Add("备注：$($Result.Note)") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("## 备份源路径") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("| 配置路径 | 展开后路径 | 状态 | 备份子目录 |") | Out-Null
    $lines.Add("| --- | --- | --- | --- |") | Out-Null

    foreach ($source in @($Result.SourcePaths)) {
        $lines.Add((
            "| {0} | {1} | {2} | {3} |" -f
            (Escape-MarkdownCell $source.configuredPath),
            (Escape-MarkdownCell $source.expandedPath),
            (Escape-MarkdownCell $source.status),
            (Escape-MarkdownCell $source.backupSubdir)
        )) | Out-Null
    }

    Set-Content -LiteralPath $Script:ConfigBackupReportPath -Value $lines -Encoding UTF8
    Write-ConfigOperationLog -Message "[报告] 已生成：$Script:ConfigBackupReportPath" -Level "SUCCESS" -LogPath $Script:ConfigBackupLogPath
}

function Get-AvailableBackups {
    param([string]$AppName)

    $safeName = ConvertTo-SafeDirectoryName -Name $AppName
    $appBackupRoot = Join-Path $Script:ConfigBackupsDir $safeName
    if (-not (Test-Path -LiteralPath $appBackupRoot)) {
        return @()
    }

    $allowedRoot = [System.IO.Path]::GetFullPath($appBackupRoot).TrimEnd("\") + "\"
    $items = @()
    foreach ($dir in @(Get-ChildItem -LiteralPath $appBackupRoot -Directory -ErrorAction SilentlyContinue)) {
        $manifestPath = Join-Path $dir.FullName "manifest.json"
        if (-not (Test-Path -LiteralPath $manifestPath)) {
            continue
        }

        $fullManifest = [System.IO.Path]::GetFullPath($manifestPath)
        if (-not $fullManifest.StartsWith($allowedRoot, [StringComparison]::OrdinalIgnoreCase)) {
            continue
        }

        try {
            $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $items += [PSCustomObject]@{
                AppName = [string]$manifest.appName
                BackupTime = [string]$manifest.backupTime
                BackupRoot = $dir.FullName
                ManifestPath = $manifestPath
                TotalFiles = [int]$manifest.totalFiles
                TotalBytes = [long]$manifest.totalBytes
                IsPreRestore = $dir.Name.StartsWith("pre_restore_", [StringComparison]::OrdinalIgnoreCase)
            }
        } catch {
            Write-ConfigOperationLog -Message "[恢复] 跳过无法解析的 manifest：$manifestPath，原因：$($_.Exception.Message)" -Level "WARN" -LogPath $Script:ConfigRestoreLogPath
        }
    }

    return @($items | Sort-Object BackupTime -Descending)
}

function Test-BackupPathAllowed {
    param(
        [string]$AppName,
        [string]$Path
    )

    $safeName = ConvertTo-SafeDirectoryName -Name $AppName
    $allowedRoot = [System.IO.Path]::GetFullPath((Join-Path $Script:ConfigBackupsDir $safeName)).TrimEnd("\") + "\"
    $fullPath = [System.IO.Path]::GetFullPath($Path)
    return $fullPath.StartsWith($allowedRoot, [StringComparison]::OrdinalIgnoreCase)
}

function Show-RestorePreview {
    param([object]$Backup)

    $manifest = Get-Content -LiteralPath $Backup.ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $overwriteFiles = @()
    $newFiles = @()
    $missingBackupFiles = @()
    $targetRoots = @{}

    foreach ($entry in @($manifest.fileList)) {
        $targetPath = if (-not [string]::IsNullOrWhiteSpace([string]$entry.originalFullPath)) {
            [string]$entry.originalFullPath
        } else {
            Join-Path ([string]$entry.sourcePath) ([string]$entry.relativePath)
        }
        $targetRoots[[string]$entry.sourcePath] = $true

        $backupFilePath = Join-Path $Backup.BackupRoot ([string]$entry.backupRelativePath)
        if (-not (Test-Path -LiteralPath $backupFilePath)) {
            $missingBackupFiles += $targetPath
        } elseif (Test-Path -LiteralPath $targetPath) {
            $overwriteFiles += $targetPath
        } else {
            $newFiles += $targetPath
        }
    }

    Write-Host ""
    Write-Host "========================================="
    Write-Host "恢复预览：$($Backup.AppName)"
    Write-Host "========================================="
    Write-Host ""
    Write-Host "使用备份：$($Backup.BackupRoot)"
    Write-Host "manifest：$($Backup.ManifestPath)"
    Write-Host "将恢复到以下原始路径："
    foreach ($root in $targetRoots.Keys) {
        Write-Host "- $root（当前存在：$(if (Test-Path -LiteralPath $root) { '是' } else { '否' })）"
    }
    Write-Host ""
    Write-Host "会覆盖文件数：$(@($overwriteFiles).Count)"
    Write-Host "会新增文件数：$(@($newFiles).Count)"
    Write-Host "备份中缺失文件数：$(@($missingBackupFiles).Count)"

    return [PSCustomObject]@{
        Manifest = $manifest
        TargetRoots = @($targetRoots.Keys)
        OverwriteFiles = @($overwriteFiles)
        NewFiles = @($newFiles)
        MissingBackupFiles = @($missingBackupFiles)
    }
}

function Backup-CurrentConfigBeforeRestore {
    param(
        [object]$App,
        [string]$Stamp
    )

    $appName = [string](Get-ConfigValue -Object $App -Name "name" -Default "未命名软件")
    $safeName = ConvertTo-SafeDirectoryName -Name $appName
    $backupRoot = Join-Path (Join-Path $Script:ConfigBackupsDir $safeName) ("pre_restore_{0}" -f $Stamp)

    Write-ConfigOperationLog -Message "[恢复前备份] 开始：$backupRoot" -Level "INFO" -LogPath $Script:ConfigRestoreLogPath
    return Invoke-ConfigBackupForApp -App $App -BackupRoot $backupRoot -LogPath $Script:ConfigRestoreLogPath
}

function Restore-ConfigFromManifest {
    param([object]$Backup)

    if (-not (Test-Path -LiteralPath $Backup.ManifestPath)) {
        throw "manifest.json 缺失，禁止恢复。"
    }
    if (-not (Test-BackupPathAllowed -AppName $Backup.AppName -Path $Backup.ManifestPath)) {
        throw "manifest 路径不在 backups/configs/$($Backup.AppName) 下，禁止恢复。"
    }

    try {
        $manifest = Get-Content -LiteralPath $Backup.ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        throw "manifest.json 解析失败，禁止恢复：$($_.Exception.Message)"
    }

    $restoredFiles = @()
    $skippedFiles = @()
    $failedFiles = @()
    $targetRoots = @{}

    foreach ($entry in @($manifest.fileList)) {
        $backupRelativePath = [string]$entry.backupRelativePath
        if ([string]::IsNullOrWhiteSpace($backupRelativePath)) {
            $skippedFiles += [PSCustomObject]@{ TargetPath = [string]$entry.originalFullPath; Reason = "manifest 缺少 backupRelativePath" }
            continue
        }

        $backupFilePath = Join-Path $Backup.BackupRoot $backupRelativePath
        if (-not (Test-BackupPathAllowed -AppName $Backup.AppName -Path $backupFilePath)) {
            $failedFiles += [PSCustomObject]@{ TargetPath = [string]$entry.originalFullPath; Reason = "备份文件路径越界" }
            continue
        }

        $targetPath = if (-not [string]::IsNullOrWhiteSpace([string]$entry.originalFullPath)) {
            [string]$entry.originalFullPath
        } else {
            Join-Path ([string]$entry.sourcePath) ([string]$entry.relativePath)
        }
        $targetRoots[[string]$entry.sourcePath] = $true

        if (-not (Test-Path -LiteralPath $backupFilePath)) {
            $failedFiles += [PSCustomObject]@{ TargetPath = $targetPath; Reason = "备份文件不存在：$backupFilePath" }
            continue
        }

        try {
            $targetDir = Split-Path -Parent $targetPath
            if (-not (Test-Path -LiteralPath $targetDir)) {
                New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
            }

            Copy-Item -LiteralPath $backupFilePath -Destination $targetPath -Force -ErrorAction Stop
            $restoredFiles += $targetPath
            Write-ConfigOperationLog -Message "[恢复] $backupFilePath -> $targetPath" -Level "DEBUG" -LogPath $Script:ConfigRestoreLogPath
        } catch {
            $failedFiles += [PSCustomObject]@{ TargetPath = $targetPath; Reason = $_.Exception.Message }
            Write-ConfigOperationLog -Message "[失败] 恢复失败：$targetPath，原因：$($_.Exception.Message)" -Level "ERROR" -LogPath $Script:ConfigRestoreLogPath
        }
    }

    return [PSCustomObject]@{
        AppName = $Backup.AppName
        BackupRoot = $Backup.BackupRoot
        ManifestPath = $Backup.ManifestPath
        RestoredFiles = @($restoredFiles)
        SkippedFiles = @($skippedFiles)
        FailedFiles = @($failedFiles)
        TargetRoots = @($targetRoots.Keys)
        Note = if (@($failedFiles).Count -eq 0) { "恢复完成" } else { "恢复完成，但存在失败文件" }
    }
}

function Generate-ConfigRestoreReport {
    param(
        [string]$AppName,
        [object]$Backup,
        [object]$PreRestoreBackup,
        [object]$RestoreResult,
        [string]$Note
    )

    $info = Get-SystemInfo
    $isAdminNow = Test-Admin
    $lines = New-Object System.Collections.Generic.List[string]

    $restoredCount = if ($null -ne $RestoreResult) { @($RestoreResult.RestoredFiles).Count } else { 0 }
    $failedCount = if ($null -ne $RestoreResult) { @($RestoreResult.FailedFiles).Count } else { 0 }
    $skippedCount = if ($null -ne $RestoreResult) { @($RestoreResult.SkippedFiles).Count } else { 0 }
    $targetRoots = if ($null -ne $RestoreResult) { @($RestoreResult.TargetRoots) } else { @() }

    $lines.Add("# 软件配置恢复报告") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("运行时间：$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))") | Out-Null
    $lines.Add("电脑名称：$($info.ComputerName)") | Out-Null
    $lines.Add("当前用户：$($info.UserName)") | Out-Null
    $lines.Add("是否管理员权限：$(if ($isAdminNow) { '是' } else { '否' })") | Out-Null
    $lines.Add("软件名称：$AppName") | Out-Null
    $lines.Add("使用的备份：$(if ($null -ne $Backup) { $Backup.BackupRoot } else { '-' })") | Out-Null
    $lines.Add("恢复前自动备份路径：$(if ($null -ne $PreRestoreBackup) { $PreRestoreBackup.BackupRoot } else { '-' })") | Out-Null
    $lines.Add("恢复文件数：$restoredCount") | Out-Null
    $lines.Add("失败文件数：$failedCount") | Out-Null
    $lines.Add("跳过文件数：$skippedCount") | Out-Null
    $lines.Add("恢复目标路径：$((@($targetRoots) -join '；'))") | Out-Null
    $lines.Add("恢复日志路径：$Script:ConfigRestoreLogPath") | Out-Null
    $lines.Add("备注：$Note") | Out-Null

    Set-Content -LiteralPath $Script:ConfigRestoreReportPath -Value $lines -Encoding UTF8
    Write-ConfigOperationLog -Message "[报告] 已生成：$Script:ConfigRestoreReportPath" -Level "SUCCESS" -LogPath $Script:ConfigRestoreLogPath
}

function Run-ConfigBackup {
    $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $Script:ConfigBackupLogPath = Join-Path $Script:UpdateLogsDir ("config_backup_{0}.log" -f $stamp)
    $Script:ConfigBackupReportPath = Join-Path $Script:UpdateReportsDir ("config_backup_{0}.md" -f $stamp)

    Initialize-BackupDirectories -LogPath $Script:ConfigBackupLogPath
    Write-ConfigOperationLog -Message "[开始] 备份软件配置（本阶段只启用 OpenClaw）" -Level "INFO" -LogPath $Script:ConfigBackupLogPath
    Write-ConfigOperationLog -Message "[安全] 不安装、不升级、不执行安装包、不修改 installers。" -Level "INFO" -LogPath $Script:ConfigBackupLogPath

    Write-ConfigOperationLog -Message "[配置] 读取 update-config.json：$Script:UpdateConfigPath" -Level "INFO" -LogPath $Script:ConfigBackupLogPath
    $updateConfig = Load-UpdateConfig -NoConsole
    $apps = @(Get-ConfiguredBackupApps -UpdateConfig $updateConfig)
    if ($apps.Count -eq 0) {
        throw "没有可备份的软件配置。本阶段需要 OpenClaw configPaths。"
    }

    Write-Host ""
    Write-Host "可备份软件："
    for ($i = 0; $i -lt $apps.Count; $i++) {
        Write-Host ("[{0}] {1}" -f ($i + 1), (Get-ConfigValue -Object $apps[$i] -Name "name" -Default "未命名软件"))
    }
    Write-Host "本阶段默认执行 OpenClaw。"

    $app = $apps[0]
    $appName = [string](Get-ConfigValue -Object $app -Name "name" -Default "OpenClaw")
    $safeName = ConvertTo-SafeDirectoryName -Name $appName
    $backupRoot = Join-Path (Join-Path $Script:ConfigBackupsDir $safeName) $stamp

    $result = Invoke-ConfigBackupForApp -App $app -BackupRoot $backupRoot -LogPath $Script:ConfigBackupLogPath
    Generate-ConfigBackupReport -Result $result

    Write-Host ""
    Write-Host "========================================="
    Write-Host "配置备份完成"
    Write-Host "========================================="
    Write-Host ""
    Write-Host "软件：$($result.AppName)"
    Write-Host "成功文件数：$($result.TotalFiles)"
    Write-Host "跳过文件数：$($result.SkippedFiles)"
    Write-Host "失败文件数：$($result.FailedFiles)"
    Write-Host "manifest：$($result.ManifestPath)"
    Write-Host "备份报告：$Script:ConfigBackupReportPath"
    Write-Host "备份日志：$Script:ConfigBackupLogPath"
    Write-Host ""
}

function Run-ConfigRestore {
    $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $Script:ConfigRestoreLogPath = Join-Path $Script:UpdateLogsDir ("config_restore_{0}.log" -f $stamp)
    $Script:ConfigRestoreReportPath = Join-Path $Script:UpdateReportsDir ("config_restore_{0}.md" -f $stamp)

    Initialize-BackupDirectories -LogPath $Script:ConfigRestoreLogPath
    Write-ConfigOperationLog -Message "[开始] 恢复软件配置（本阶段只启用 OpenClaw）" -Level "INFO" -LogPath $Script:ConfigRestoreLogPath
    Write-ConfigOperationLog -Message "[安全] 恢复前必须自动备份当前配置；只覆盖 manifest 记录过的文件。" -Level "INFO" -LogPath $Script:ConfigRestoreLogPath

    Write-ConfigOperationLog -Message "[配置] 读取 update-config.json：$Script:UpdateConfigPath" -Level "INFO" -LogPath $Script:ConfigRestoreLogPath
    $updateConfig = Load-UpdateConfig -NoConsole
    $apps = @(Get-ConfiguredBackupApps -UpdateConfig $updateConfig)
    if ($apps.Count -eq 0) {
        throw "没有可恢复的软件配置。本阶段需要 OpenClaw configPaths。"
    }

    $app = $apps[0]
    $appName = [string](Get-ConfigValue -Object $app -Name "name" -Default "OpenClaw")
    $backups = @(Get-AvailableBackups -AppName $appName)
    if ($backups.Count -eq 0) {
        Write-ConfigOperationLog -Message "[恢复] 未找到 OpenClaw 历史备份。" -Level "WARN" -LogPath $Script:ConfigRestoreLogPath
        Generate-ConfigRestoreReport -AppName $appName -Backup $null -PreRestoreBackup $null -RestoreResult $null -Note "未找到历史备份，未执行恢复"
        return
    }

    Write-Host ""
    Write-Host "可恢复备份："
    for ($i = 0; $i -lt $backups.Count; $i++) {
        $backup = $backups[$i]
        $kind = if ($backup.IsPreRestore) { "恢复前备份" } else { "普通备份" }
        Write-Host ("[{0}] {1} | {2} | 文件：{3} | 大小：{4} | manifest：{5}" -f ($i + 1), $backup.BackupTime, $kind, $backup.TotalFiles, (ConvertTo-SizeText -Bytes $backup.TotalBytes), $backup.ManifestPath)
    }

    $choice = Read-Host "请输入要恢复的备份序号（直接回车取消）"
    if ([string]::IsNullOrWhiteSpace($choice)) {
        Write-ConfigOperationLog -Message "[恢复] 用户取消：未选择备份。" -Level "WARN" -LogPath $Script:ConfigRestoreLogPath
        Generate-ConfigRestoreReport -AppName $appName -Backup $null -PreRestoreBackup $null -RestoreResult $null -Note "用户取消：未选择备份"
        return
    }
    if (-not ($choice -match "^\d+$") -or [int]$choice -lt 1 -or [int]$choice -gt $backups.Count) {
        Write-ConfigOperationLog -Message "[恢复] 无效序号：$choice" -Level "ERROR" -LogPath $Script:ConfigRestoreLogPath
        Generate-ConfigRestoreReport -AppName $appName -Backup $null -PreRestoreBackup $null -RestoreResult $null -Note "无效序号：$choice"
        return
    }

    $selected = $backups[[int]$choice - 1]
    if (-not (Test-BackupPathAllowed -AppName $appName -Path $selected.ManifestPath)) {
        Write-ConfigOperationLog -Message "[恢复] 备份路径越界，禁止恢复：$($selected.ManifestPath)" -Level "ERROR" -LogPath $Script:ConfigRestoreLogPath
        Generate-ConfigRestoreReport -AppName $appName -Backup $selected -PreRestoreBackup $null -RestoreResult $null -Note "备份路径越界，禁止恢复"
        return
    }

    $preview = Show-RestorePreview -Backup $selected
    Write-ConfigOperationLog -Message "[预览] 覆盖：$(@($preview.OverwriteFiles).Count)，新增：$(@($preview.NewFiles).Count)，缺失：$(@($preview.MissingBackupFiles).Count)" -Level "INFO" -LogPath $Script:ConfigRestoreLogPath

    $preRestoreBackup = Backup-CurrentConfigBeforeRestore -App $app -Stamp $stamp
    if (-not $preRestoreBackup.Success -or $preRestoreBackup.FailedFiles -gt 0) {
        Write-ConfigOperationLog -Message "[恢复] 恢复前备份失败，禁止继续恢复。" -Level "ERROR" -LogPath $Script:ConfigRestoreLogPath
        Generate-ConfigRestoreReport -AppName $appName -Backup $selected -PreRestoreBackup $preRestoreBackup -RestoreResult $null -Note "恢复前备份失败，未执行恢复"
        return
    }

    Write-Host ""
    Write-Host "你即将把 OpenClaw 配置恢复到备份时状态，可能覆盖当前配置。"
    Write-Host "已自动备份当前配置到 $($preRestoreBackup.BackupRoot)。"
    $confirm = Read-Host "请输入 YES 继续"
    Write-ConfigOperationLog -Message "[恢复] 用户确认输入：$confirm" -Level "INFO" -LogPath $Script:ConfigRestoreLogPath
    if ($confirm -ne "YES") {
        Write-ConfigOperationLog -Message "[恢复] 用户未输入 YES，已取消恢复。" -Level "WARN" -LogPath $Script:ConfigRestoreLogPath
        Generate-ConfigRestoreReport -AppName $appName -Backup $selected -PreRestoreBackup $preRestoreBackup -RestoreResult $null -Note "用户未输入 YES，已取消恢复"
        return
    }

    $restoreResult = Restore-ConfigFromManifest -Backup $selected
    Generate-ConfigRestoreReport -AppName $appName -Backup $selected -PreRestoreBackup $preRestoreBackup -RestoreResult $restoreResult -Note $restoreResult.Note

    Write-Host ""
    Write-Host "========================================="
    Write-Host "配置恢复完成"
    Write-Host "========================================="
    Write-Host ""
    Write-Host "恢复文件数：$(@($restoreResult.RestoredFiles).Count)"
    Write-Host "跳过文件数：$(@($restoreResult.SkippedFiles).Count)"
    Write-Host "失败文件数：$(@($restoreResult.FailedFiles).Count)"
    Write-Host "恢复前备份：$($preRestoreBackup.BackupRoot)"
    Write-Host "恢复报告：$Script:ConfigRestoreReportPath"
    Write-Host "恢复日志：$Script:ConfigRestoreLogPath"
    Write-Host ""
}

function Write-SafeUpgradeLog {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS", "DEBUG")][string]$Level = "INFO",
        [switch]$NoConsole
    )

    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[{0}] [{1}] {2}" -f $time, $Level, $Message

    if (-not [string]::IsNullOrWhiteSpace($Script:SafeUpgradeLogPath)) {
        try {
            Add-Content -LiteralPath $Script:SafeUpgradeLogPath -Value $line -Encoding UTF8
        } catch {
            Write-Host "[安全升级日志错误] 无法写入日志：$($_.Exception.Message)" -ForegroundColor Red
        }
    }

    if (-not $NoConsole) {
        switch ($Level) {
            "WARN"    { Write-Host $Message -ForegroundColor Yellow }
            "ERROR"   { Write-Host $Message -ForegroundColor Red }
            "SUCCESS" { Write-Host $Message -ForegroundColor Green }
            "DEBUG"   { Write-Host $Message -ForegroundColor DarkGray }
            default   { Write-Host $Message }
        }
    }
}

function Initialize-SafeUpgradeDirectories {
    foreach ($dir in @($Script:BackupsDir, $Script:ConfigBackupsDir, $Script:InstallerBackupsDir, $Script:UpdateReportsDir, $Script:UpdateLogsDir)) {
        if (-not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-SafeUpgradeLog -Message "[目录] 已创建：$dir" -Level "INFO"
        }
    }
}

function Get-SafeUpgradeApps {
    param([object]$UpdateConfig)

    $apps = @()
    foreach ($app in @($UpdateConfig.apps)) {
        $name = [string](Get-ConfigValue -Object $app -Name "name" -Default "")
        if ($name -eq "OpenClaw" -and (Get-BoolConfig -Object $app -Name "enabled" -Default $true)) {
            $apps += $app
        } elseif (-not [string]::IsNullOrWhiteSpace($name)) {
            Write-SafeUpgradeLog -Message "[跳过] $name 不支持 v2.4 安全升级。" -Level "DEBUG" -NoConsole
        }
    }

    return @($apps)
}

function Get-AppConfigByName {
    param(
        [object]$Config,
        [string]$Name
    )

    foreach ($app in @($Config.apps)) {
        if ([string](Get-ConfigValue -Object $app -Name "name" -Default "") -eq $Name) {
            return $app
        }
    }

    return $null
}

function Get-SafeUpgradeCurrentVersion {
    param([object]$App)

    $name = [string](Get-ConfigValue -Object $App -Name "name" -Default "未命名软件")
    $methods = Get-UpdateDetectMethods -App $App
    Write-SafeUpgradeLog -Message "[检测] $name 当前安装状态，方式：$($methods -join ', ')" -Level "INFO"

    foreach ($method in $methods) {
        switch ($method) {
            "command" {
                $command = [string](Get-ConfigValue -Object $App -Name "versionCommand" -Default "")
                if ([string]::IsNullOrWhiteSpace($command)) {
                    continue
                }

                $result = Invoke-UpdateCommandText -CommandText $command -TimeoutSeconds 30
                if ($result.ExitCode -eq 0) {
                    $version = Get-VersionFromText -Text $result.Output
                    if (-not [string]::IsNullOrWhiteSpace($version)) {
                        Write-SafeUpgradeLog -Message "[检测] 命令检测成功：$version" -Level "SUCCESS"
                        return [PSCustomObject]@{ Installed = $true; Version = $version; Source = "命令：$command"; Note = "命令检测成功" }
                    }
                }
            }
            "registry" {
                $registryNames = ConvertTo-StringArray (Get-ConfigValue -Object $App -Name "registryNames" -Default @())
                $registryResult = Get-InstalledAppByRegistry -RegistryNames $registryNames
                if ($null -ne $registryResult) {
                    $version = Get-VersionFromText -Text $registryResult.DisplayVersion
                    Write-SafeUpgradeLog -Message "[检测] 注册表检测到：$($registryResult.DisplayName)，版本：$(if ($version) { $version } else { '未知' })" -Level "SUCCESS"
                    return [PSCustomObject]@{ Installed = $true; Version = $version; Source = "注册表：$($registryResult.DisplayName)"; Note = $registryResult.RegistryPath }
                }
            }
            { $_ -in @("path", "file") } {
                $installPath = Get-FirstExistingInstallPath -App $App
                if (-not [string]::IsNullOrWhiteSpace($installPath)) {
                    $version = Get-FileVersionFromPath -Path $installPath
                    Write-SafeUpgradeLog -Message "[检测] 文件检测到：$installPath，版本：$(if ($version) { $version } else { '未知' })" -Level "SUCCESS"
                    return [PSCustomObject]@{ Installed = $true; Version = $version; Source = "文件：$installPath"; Note = "文件版本检测" }
                }
            }
        }
    }

    Write-SafeUpgradeLog -Message "[检测] 未检测到 $name 已安装。" -Level "WARN"
    return [PSCustomObject]@{ Installed = $false; Version = ""; Source = "未检测到"; Note = "无法识别当前版本或安装状态" }
}

function Get-TargetInstallerInfo {
    param([object]$App)

    $appName = [string](Get-ConfigValue -Object $App -Name "name" -Default "OpenClaw")
    $safeName = ConvertTo-SafeDirectoryName -Name $appName
    $installerName = [string](Get-ConfigValue -Object $App -Name "installerFileName" -Default "openclaw.exe")
    $path = Join-Path (Join-Path $Script:DownloadsLatestDir $safeName) $installerName

    Write-SafeUpgradeLog -Message "[目标包] 检查目标安装包：$path" -Level "INFO"
    if (-not (Test-Path -LiteralPath $path)) {
        return [PSCustomObject]@{
            Ready = $false; Path = $path; FileName = $installerName; SizeBytes = 0L; SizeText = "-"; Extension = "";
            SignatureStatus = "-"; Signer = "-"; TargetVersion = ""; VersionText = "目标版本未知"; Message = "目标安装包不存在"
        }
    }

    try {
        $item = Get-Item -LiteralPath $path -ErrorAction Stop
        $extension = [System.IO.Path]::GetExtension($item.Name).ToLowerInvariant()
        $signature = Get-FileSignatureInfo -Path $path
        $versionRaw = [string]$item.VersionInfo.ProductVersion
        if ([string]::IsNullOrWhiteSpace($versionRaw)) {
            $versionRaw = [string]$item.VersionInfo.FileVersion
        }
        $version = Get-VersionFromText -Text $versionRaw
        $messages = @()
        $ready = $true

        if ($item.Length -le 0) {
            $ready = $false
            $messages += "文件大小为 0"
        }
        if ($extension -ne ".exe") {
            $ready = $false
            $messages += "扩展名不是 .exe：$extension"
        }
        if ($signature.Status -ne "Valid") {
            $ready = $false
            $messages += "签名无效或未知：$($signature.Status)"
        }
        if ($messages.Count -eq 0) {
            $messages += "目标安装包校验通过"
        }

        Write-SafeUpgradeLog -Message "[目标包] 大小：$(ConvertTo-SizeText -Bytes $item.Length)，签名：$($signature.Status)，版本：$(if ($version) { $version } else { '目标版本未知' })" -Level "INFO"
        return [PSCustomObject]@{
            Ready = $ready
            Path = $item.FullName
            FileName = $item.Name
            SizeBytes = [long]$item.Length
            SizeText = ConvertTo-SizeText -Bytes $item.Length
            Extension = $extension
            SignatureStatus = $signature.Status
            Signer = if ([string]::IsNullOrWhiteSpace($signature.Signer)) { "-" } else { $signature.Signer }
            TargetVersion = $version
            VersionText = if (-not [string]::IsNullOrWhiteSpace($version)) { $version } else { "目标版本未知" }
            Message = ($messages -join "；")
        }
    } catch {
        return [PSCustomObject]@{
            Ready = $false; Path = $path; FileName = $installerName; SizeBytes = 0L; SizeText = "-"; Extension = "";
            SignatureStatus = "-"; Signer = "-"; TargetVersion = ""; VersionText = "目标版本未知"; Message = "目标安装包检查失败：$($_.Exception.Message)"
        }
    }
}

function Compare-AppVersionForUpgrade {
    param(
        [object]$Current,
        [object]$Target
    )

    $currentVersion = [string]$Current.Version
    $targetVersion = [string]$Target.TargetVersion
    $currentText = if (-not [string]::IsNullOrWhiteSpace($currentVersion)) { $currentVersion } elseif ($Current.Installed) { "未知" } else { "未安装" }
    $targetText = if (-not [string]::IsNullOrWhiteSpace($targetVersion)) { $targetVersion } else { "未知" }

    if (-not $Current.Installed) {
        return [PSCustomObject]@{
            State = "需要 FORCE"
            CanContinue = $true
            RequiresForce = $true
            RequiresDowngrade = $false
            Note = "未检测到已安装 OpenClaw；安全升级模式默认不执行首次安装，必须输入 FORCE 才允许继续"
        }
    }

    if ([string]::IsNullOrWhiteSpace($currentVersion) -and [string]::IsNullOrWhiteSpace($targetVersion)) {
        return [PSCustomObject]@{
            State = "需要 FORCE"
            CanContinue = $true
            RequiresForce = $true
            RequiresDowngrade = $false
            Note = "当前版本未知，目标版本未知，必须输入 FORCE"
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($currentVersion) -and [string]::IsNullOrWhiteSpace($targetVersion)) {
        return [PSCustomObject]@{
            State = "需要 FORCE"
            CanContinue = $true
            RequiresForce = $true
            RequiresDowngrade = $false
            Note = "当前版本已知，目标版本未知，无法确认是否新版，必须输入 FORCE"
        }
    }

    if ([string]::IsNullOrWhiteSpace($currentVersion) -and -not [string]::IsNullOrWhiteSpace($targetVersion)) {
        return [PSCustomObject]@{
            State = "需要 FORCE"
            CanContinue = $true
            RequiresForce = $true
            RequiresDowngrade = $false
            Note = "当前版本未知，目标版本 $targetVersion，必须输入 FORCE"
        }
    }

    $currentObject = ConvertTo-VersionObject -VersionText $currentVersion
    $targetObject = ConvertTo-VersionObject -VersionText $targetVersion
    if ($null -eq $currentObject -or $null -eq $targetObject) {
        return [PSCustomObject]@{
            State = "需要 FORCE"
            CanContinue = $true
            RequiresForce = $true
            RequiresDowngrade = $false
            Note = "版本无法解析，当前：$currentText，目标：$targetText，必须输入 FORCE"
        }
    }

    if ($targetObject -gt $currentObject) {
        return [PSCustomObject]@{
            State = "允许升级"
            CanContinue = $true
            RequiresForce = $false
            RequiresDowngrade = $false
            Note = "目标版本高于当前版本"
        }
    }

    if ($targetObject -eq $currentObject) {
        return [PSCustomObject]@{
            State = "需要 FORCE"
            CanContinue = $true
            RequiresForce = $true
            RequiresDowngrade = $false
            Note = "目标版本等于当前版本，默认不覆盖安装，必须输入 FORCE"
        }
    }

    return [PSCustomObject]@{
        State = "需要 DOWNGRADE"
        CanContinue = $true
        RequiresForce = $false
        RequiresDowngrade = $true
        Note = "目标版本低于当前版本，必须输入 DOWNGRADE"
    }
}

function Backup-InstallerBeforeUpgrade {
    param(
        [object]$ConfigApp,
        [string]$Stamp
    )

    $appName = [string](Get-ConfigValue -Object $ConfigApp -Name "name" -Default "OpenClaw")
    $installerName = [string](Get-ConfigValue -Object $ConfigApp -Name "installer" -Default "openclaw.exe")
    $sourcePath = Join-Path $Script:InstallersDir $installerName
    $safeName = ConvertTo-SafeDirectoryName -Name $appName
    $backupDir = Join-Path (Join-Path $Script:InstallerBackupsDir $safeName) $Stamp
    $backupPath = Join-Path $backupDir $installerName

    if (-not (Test-Path -LiteralPath $sourcePath)) {
        Write-SafeUpgradeLog -Message "[安装包备份] 未发现旧安装包：$sourcePath" -Level "WARN"
        return [PSCustomObject]@{ Success = $true; Found = $false; SourcePath = $sourcePath; BackupPath = ""; Message = "未发现旧安装包" }
    }

    try {
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
        Copy-Item -LiteralPath $sourcePath -Destination $backupPath -Force -ErrorAction Stop
        Write-SafeUpgradeLog -Message "[安装包备份] 已备份旧安装包：$backupPath" -Level "SUCCESS"
        return [PSCustomObject]@{ Success = $true; Found = $true; SourcePath = $sourcePath; BackupPath = $backupPath; Message = "旧安装包备份完成" }
    } catch {
        Write-SafeUpgradeLog -Message "[安装包备份] 失败：$($_.Exception.Message)" -Level "ERROR"
        return [PSCustomObject]@{ Success = $false; Found = $true; SourcePath = $sourcePath; BackupPath = $backupPath; Message = "旧安装包备份失败：$($_.Exception.Message)" }
    }
}

function Backup-ConfigBeforeUpgrade {
    param(
        [object]$App,
        [string]$Stamp
    )

    $appName = [string](Get-ConfigValue -Object $App -Name "name" -Default "OpenClaw")
    $safeName = ConvertTo-SafeDirectoryName -Name $appName
    $backupRoot = Join-Path (Join-Path $Script:ConfigBackupsDir $safeName) ("pre_upgrade_{0}" -f $Stamp)

    Write-SafeUpgradeLog -Message "[配置备份] 升级前配置备份：$backupRoot" -Level "INFO"
    $backup = Invoke-ConfigBackupForApp -App $App -BackupRoot $backupRoot -LogPath $Script:SafeUpgradeLogPath
    $existingSources = @($backup.SourcePaths | Where-Object { $_.exists })
    $hasExistingConfig = ($existingSources.Count -gt 0)
    $failed = (-not $backup.Success) -or ($backup.FailedFiles -gt 0)

    if ($hasExistingConfig -and $failed) {
        return [PSCustomObject]@{ Success = $false; HasExistingConfig = $true; Backup = $backup; Message = "配置备份失败，已中止升级" }
    }

    if (-not $hasExistingConfig) {
        return [PSCustomObject]@{ Success = $true; HasExistingConfig = $false; Backup = $backup; Message = "未发现配置路径" }
    }

    return [PSCustomObject]@{ Success = $true; HasExistingConfig = $true; Backup = $backup; Message = "配置备份完成" }
}

function Get-SafeUpgradeInstallAttempts {
    param(
        [object]$ConfigApp,
        [string]$InstallerPath
    )

    $type = ([string](Get-ConfigValue -Object $ConfigApp -Name "type" -Default "exe")).ToLowerInvariant()
    $silentArgs = ConvertTo-StringArray (Get-ConfigValue -Object $ConfigApp -Name "silentArgs" -Default @())
    $fallbackArgs = ConvertTo-StringArray (Get-ConfigValue -Object $ConfigApp -Name "fallbackArgs" -Default @())
    $attempts = @()

    if ($type -eq "msi") {
        if ($silentArgs.Count -eq 0) {
            $silentArgs = @("/qn /norestart")
        }
        foreach ($arg in $silentArgs) {
            $attempts += [PSCustomObject]@{ Label = "静默安装"; FilePath = "msiexec.exe"; Arguments = "/i `"$InstallerPath`" $arg" }
        }
        foreach ($arg in $fallbackArgs) {
            $attempts += [PSCustomObject]@{ Label = "备用参数"; FilePath = "msiexec.exe"; Arguments = "/i `"$InstallerPath`" $arg" }
        }
    } else {
        foreach ($arg in $silentArgs) {
            $attempts += [PSCustomObject]@{ Label = "静默安装"; FilePath = $InstallerPath; Arguments = $arg }
        }
        foreach ($arg in $fallbackArgs) {
            $attempts += [PSCustomObject]@{ Label = "备用参数"; FilePath = $InstallerPath; Arguments = $arg }
        }
    }

    return @($attempts)
}

function Show-SafeUpgradePreview {
    param(
        [object]$Current,
        [object]$Target,
        [object]$ConfigBackup,
        [object]$InstallerBackup,
        [object[]]$Attempts,
        [object]$VersionDecision
    )

    $planned = if (@($Attempts).Count -gt 0) {
        if ([string]::IsNullOrWhiteSpace($Attempts[0].Arguments)) { "`"$($Attempts[0].FilePath)`"" } else { "`"$($Attempts[0].FilePath)`" $($Attempts[0].Arguments)" }
    } else {
        "未配置安装命令"
    }

    Write-Host ""
    Write-Host "========================================="
    Write-Host "OpenClaw 安全升级预览"
    Write-Host "========================================="
    Write-Host ""
    Write-Host "当前版本：$(if ($Current.Version) { $Current.Version } elseif ($Current.Installed) { '未知' } else { '未安装' })"
    Write-Host "当前检测来源：$($Current.Source)"
    Write-Host "目标安装包路径：$($Target.Path)"
    Write-Host "目标版本：$($Target.VersionText)"
    Write-Host "目标文件大小：$($Target.SizeText)"
    Write-Host "数字签名状态：$($Target.SignatureStatus)"
    Write-Host "签名者：$($Target.Signer)"
    Write-Host "配置备份路径：$($ConfigBackup.Backup.BackupRoot)"
    Write-Host "当前安装包备份路径：$(if ($InstallerBackup.BackupPath) { $InstallerBackup.BackupPath } else { $InstallerBackup.Message })"
    Write-Host "将执行的安装命令：$planned"
    Write-Host "版本判断：$($VersionDecision.State)；$($VersionDecision.Note)"
    Write-Host ""
    Write-Host "风险提示：升级可能影响登录状态、配置或运行状态；本工具不会自动恢复配置，也不会替换 installers。"
    Write-Host ""

    Write-SafeUpgradeLog -Message "[预览] 命令：$planned" -Level "INFO"
    return $planned
}

function Confirm-SafeUpgrade {
    param([object]$VersionDecision)

    Write-Host ""
    Write-Host "你即将升级 OpenClaw。"
    Write-Host "升级前已完成配置备份和安装包备份。"
    Write-Host "升级可能影响登录状态、配置或运行状态。"
    $yes = Read-Host "请输入 YES 继续升级"
    Write-SafeUpgradeLog -Message "[确认] YES 输入：$yes" -Level "INFO"

    $force = ""
    $downgrade = ""
    if ($yes -eq "YES" -and $VersionDecision.RequiresForce) {
        $force = Read-Host "版本相同或版本未知，请输入 FORCE 继续"
        Write-SafeUpgradeLog -Message "[确认] FORCE 输入：$force" -Level "INFO"
    }
    if ($yes -eq "YES" -and $VersionDecision.RequiresDowngrade) {
        $downgrade = Read-Host "检测到降级风险，请输入 DOWNGRADE 继续"
        Write-SafeUpgradeLog -Message "[确认] DOWNGRADE 输入：$downgrade" -Level "WARN"
    }

    $confirmed = ($yes -eq "YES")
    $forceConfirmed = (-not $VersionDecision.RequiresForce) -or ($force -eq "FORCE")
    $downgradeConfirmed = (-not $VersionDecision.RequiresDowngrade) -or ($downgrade -eq "DOWNGRADE")

    return [PSCustomObject]@{
        UserInput = $yes
        ForceInput = $force
        DowngradeInput = $downgrade
        Confirmed = ($confirmed -and $forceConfirmed -and $downgradeConfirmed)
        ForceConfirmed = ($force -eq "FORCE")
        DowngradeConfirmed = ($downgrade -eq "DOWNGRADE")
        Message = if (-not $confirmed) { "用户未输入 YES，已取消升级" } elseif (-not $forceConfirmed) { "未输入 FORCE，已取消升级" } elseif (-not $downgradeConfirmed) { "未输入 DOWNGRADE，已取消升级" } else { "用户已确认升级" }
    }
}

function Invoke-SafeUpgradeInstaller {
    param(
        [object[]]$Attempts,
        [int]$TimeoutMinutes = 20
    )

    if (@($Attempts).Count -eq 0) {
        return [PSCustomObject]@{ Success = $false; Attempted = $false; ExitCode = 1; Command = ""; Message = "未配置 silentArgs 或 fallbackArgs，为避免卡住，不执行交互式安装" }
    }

    $timeoutMs = [int]([TimeSpan]::FromMinutes($TimeoutMinutes).TotalMilliseconds)
    $last = $null
    foreach ($attempt in @($Attempts)) {
        $commandText = if ([string]::IsNullOrWhiteSpace($attempt.Arguments)) { "`"$($attempt.FilePath)`"" } else { "`"$($attempt.FilePath)`" $($attempt.Arguments)" }
        Write-SafeUpgradeLog -Message "[执行] $commandText" -Level "INFO"

        try {
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = [string]$attempt.FilePath
            $psi.Arguments = [string]$attempt.Arguments
            $psi.WorkingDirectory = Split-Path -Parent ([string]$attempt.FilePath)
            $psi.UseShellExecute = $false

            $process = New-Object System.Diagnostics.Process
            $process.StartInfo = $psi
            [void]$process.Start()

            if (-not $process.WaitForExit($timeoutMs)) {
                try { $process.Kill() } catch {}
                $last = [PSCustomObject]@{ Success = $false; Attempted = $true; ExitCode = 124; Command = $commandText; Message = "安装程序超时（${TimeoutMinutes} 分钟）" }
                Write-SafeUpgradeLog -Message "[执行] 超时：$commandText" -Level "ERROR"
                continue
            }

            $exitCode = $process.ExitCode
            Write-SafeUpgradeLog -Message "[执行] 返回码：$exitCode" -Level "INFO"
            if ($exitCode -eq 0 -or $exitCode -eq 3010) {
                return [PSCustomObject]@{ Success = $true; Attempted = $true; ExitCode = $exitCode; Command = $commandText; Message = if ($exitCode -eq 3010) { "安装完成，提示需要重启" } else { "安装程序返回成功" } }
            }

            $last = [PSCustomObject]@{ Success = $false; Attempted = $true; ExitCode = $exitCode; Command = $commandText; Message = "安装程序返回非 0 代码：$exitCode" }
        } catch {
            $last = [PSCustomObject]@{ Success = $false; Attempted = $true; ExitCode = 1; Command = $commandText; Message = "启动安装程序失败：$($_.Exception.Message)" }
            Write-SafeUpgradeLog -Message "[执行] 失败：$($_.Exception.Message)" -Level "ERROR"
        }
    }

    if ($null -eq $last) {
        return [PSCustomObject]@{ Success = $false; Attempted = $false; ExitCode = 1; Command = ""; Message = "没有执行任何安装尝试" }
    }

    return $last
}

function Test-AppAfterUpgrade {
    param([object]$App)

    Start-Sleep -Seconds 2
    $current = Get-SafeUpgradeCurrentVersion -App $App
    $configPaths = ConvertTo-StringArray (Get-ConfigValue -Object $App -Name "configPaths" -Default @())
    $existingPaths = @()
    foreach ($path in $configPaths) {
        $expanded = Expand-ConfigPath -Path $path
        if (Test-Path -LiteralPath $expanded) {
            $existingPaths += $expanded
        }
    }

    return [PSCustomObject]@{
        Installed = $current.Installed
        Version = $current.Version
        Source = $current.Source
        ExistingConfigPaths = @($existingPaths)
        Note = $current.Note
    }
}

function Generate-SafeUpgradeReport {
    param([object]$Result)

    $info = Get-SystemInfo
    $isAdminNow = Test-Admin
    $lines = New-Object System.Collections.Generic.List[string]

    $lines.Add("# 安全升级报告") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("运行时间：$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))") | Out-Null
    $lines.Add("电脑名称：$($info.ComputerName)") | Out-Null
    $lines.Add("当前用户：$($info.UserName)") | Out-Null
    $lines.Add("是否管理员权限：$(if ($isAdminNow) { '是' } else { '否' })") | Out-Null
    $lines.Add("软件名称：$($Result.SoftwareName)") | Out-Null
    $lines.Add("当前版本：$($Result.CurrentVersion)") | Out-Null
    $lines.Add("目标版本：$($Result.TargetVersion)") | Out-Null
    $lines.Add("目标安装包路径：$($Result.TargetInstallerPath)") | Out-Null
    $lines.Add("目标安装包大小：$($Result.TargetInstallerSize)") | Out-Null
    $lines.Add("目标安装包签名状态：$($Result.TargetSignatureStatus)") | Out-Null
    $lines.Add("签名者：$($Result.TargetSigner)") | Out-Null
    $lines.Add("配置备份路径：$($Result.ConfigBackupPath)") | Out-Null
    $lines.Add("installers 旧安装包备份路径：$($Result.OldInstallerBackupPath)") | Out-Null
    $lines.Add("用户确认结果：$($Result.UserConfirmResult)") | Out-Null
    $lines.Add("是否 FORCE：$($Result.IsForce)") | Out-Null
    $lines.Add("是否 DOWNGRADE：$($Result.IsDowngrade)") | Out-Null
    $lines.Add("执行命令：$($Result.ExecuteCommand)") | Out-Null
    $lines.Add("安装返回码：$($Result.ExitCode)") | Out-Null
    $lines.Add("升级后版本：$($Result.AfterVersion)") | Out-Null
    $lines.Add("升级结果：$($Result.UpgradeResult)") | Out-Null
    $lines.Add("失败原因：$($Result.FailureReason)") | Out-Null
    $lines.Add("备注：$($Result.Note)") | Out-Null
    $lines.Add("升级日志路径：$Script:SafeUpgradeLogPath") | Out-Null

    Set-Content -LiteralPath $Script:SafeUpgradeReportPath -Value $lines -Encoding UTF8
    Write-SafeUpgradeLog -Message "[报告] 已生成：$Script:SafeUpgradeReportPath" -Level "SUCCESS"
}

function Show-SafeUpgradeSummary {
    param([object]$Result)

    Write-Host ""
    Write-Host "========================================="
    Write-Host "安全升级模式完成"
    Write-Host "========================================="
    Write-Host ""
    Write-Host "升级结果：$($Result.UpgradeResult)"
    if (-not [string]::IsNullOrWhiteSpace([string]$Result.FailureReason)) {
        Write-Host "原因：$($Result.FailureReason)"
    }
    Write-Host "升级报告：$Script:SafeUpgradeReportPath"
    Write-Host "升级日志：$Script:SafeUpgradeLogPath"
    Write-Host ""
}

function Run-SafeUpgradeMode {
    $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $Script:SafeUpgradeLogPath = Join-Path $Script:UpdateLogsDir ("safe_upgrade_{0}.log" -f $stamp)
    $Script:SafeUpgradeReportPath = Join-Path $Script:UpdateReportsDir ("safe_upgrade_{0}.md" -f $stamp)

    Initialize-SafeUpgradeDirectories
    Write-SafeUpgradeLog -Message "[开始] 安全升级模式（v2.4 仅允许 OpenClaw）" -Level "INFO"
    Write-SafeUpgradeLog -Message "[安全] 不联网下载、不替换 installers、不跳过备份、不自动恢复配置。" -Level "INFO"

    $result = [PSCustomObject]@{
        SoftwareName = "OpenClaw"
        CurrentVersion = "-"
        TargetVersion = "-"
        TargetInstallerPath = "-"
        TargetInstallerSize = "-"
        TargetSignatureStatus = "-"
        TargetSigner = "-"
        ConfigBackupPath = "-"
        OldInstallerBackupPath = "-"
        UserConfirmResult = "未确认"
        IsForce = "否"
        IsDowngrade = "否"
        ExecuteCommand = "-"
        ExitCode = "-"
        AfterVersion = "-"
        UpgradeResult = "失败"
        FailureReason = ""
        Note = ""
    }

    try {
        Write-SafeUpgradeLog -Message "[配置] 读取 update-config.json：$Script:UpdateConfigPath" -Level "INFO"
        $updateConfig = Load-UpdateConfig -NoConsole
        Write-SafeUpgradeLog -Message "[配置] 读取 config.json：$Script:ConfigPath" -Level "INFO"
        $installConfig = Load-Config

        $safeApps = @(Get-SafeUpgradeApps -UpdateConfig $updateConfig)
        Write-Host ""
        Write-Host "可安全升级软件："
        if ($safeApps.Count -gt 0) {
            for ($i = 0; $i -lt $safeApps.Count; $i++) {
                Write-Host ("[{0}] {1}" -f ($i + 1), (Get-ConfigValue -Object $safeApps[$i] -Name "name" -Default "未命名软件"))
            }
            Write-Host "其他软件：不支持 v2.4 安全升级。"
        } else {
            Write-Host "没有可安全升级的软件。"
            $result.UpgradeResult = "跳过"
            $result.FailureReason = "没有可安全升级的软件"
            Generate-SafeUpgradeReport -Result $result
            Show-SafeUpgradeSummary -Result $result
            return
        }

        $app = $safeApps[0]
        $configApp = Get-AppConfigByName -Config $installConfig -Name "OpenClaw"
        if ($null -eq $configApp) {
            $configApp = $app
        }

        $current = Get-SafeUpgradeCurrentVersion -App $app
        $result.CurrentVersion = if (-not [string]::IsNullOrWhiteSpace($current.Version)) { $current.Version } elseif ($current.Installed) { "未知" } else { "未安装" }

        $target = Get-TargetInstallerInfo -App $app
        $result.TargetInstallerPath = $target.Path
        $result.TargetInstallerSize = $target.SizeText
        $result.TargetSignatureStatus = $target.SignatureStatus
        $result.TargetSigner = $target.Signer
        $result.TargetVersion = $target.VersionText

        if (-not $target.Ready) {
            $result.UpgradeResult = "禁止"
            $result.FailureReason = $target.Message
            Generate-SafeUpgradeReport -Result $result
            Show-SafeUpgradeSummary -Result $result
            return
        }

        $versionDecision = Compare-AppVersionForUpgrade -Current $current -Target $target
        Write-SafeUpgradeLog -Message "[版本比较] $($versionDecision.State)：$($versionDecision.Note)" -Level "INFO"

        $configBackup = Backup-ConfigBeforeUpgrade -App $app -Stamp $stamp
        $result.ConfigBackupPath = $configBackup.Backup.BackupRoot
        if (-not $configBackup.Success) {
            $result.UpgradeResult = "禁止"
            $result.FailureReason = $configBackup.Message
            Generate-SafeUpgradeReport -Result $result
            Show-SafeUpgradeSummary -Result $result
            return
        }

        $installerBackup = Backup-InstallerBeforeUpgrade -ConfigApp $configApp -Stamp $stamp
        $result.OldInstallerBackupPath = if ($installerBackup.BackupPath) { $installerBackup.BackupPath } else { $installerBackup.Message }
        if (-not $installerBackup.Success) {
            $result.UpgradeResult = "禁止"
            $result.FailureReason = $installerBackup.Message
            Generate-SafeUpgradeReport -Result $result
            Show-SafeUpgradeSummary -Result $result
            return
        }

        $attempts = @(Get-SafeUpgradeInstallAttempts -ConfigApp $configApp -InstallerPath $target.Path)
        $plannedCommand = Show-SafeUpgradePreview -Current $current -Target $target -ConfigBackup $configBackup -InstallerBackup $installerBackup -Attempts $attempts -VersionDecision $versionDecision
        $result.ExecuteCommand = $plannedCommand

        $confirm = Confirm-SafeUpgrade -VersionDecision $versionDecision
        $result.UserConfirmResult = $confirm.Message
        $result.IsForce = if ($confirm.ForceConfirmed) { "是" } else { "否" }
        $result.IsDowngrade = if ($confirm.DowngradeConfirmed) { "是" } else { "否" }
        if (-not $confirm.Confirmed) {
            $result.UpgradeResult = "跳过"
            $result.FailureReason = $confirm.Message
            $result.Note = "已完成升级前备份，但未执行安装包"
            Generate-SafeUpgradeReport -Result $result
            Show-SafeUpgradeSummary -Result $result
            return
        }

        $timeout = [int](Get-ConfigValue -Object $installConfig.settings -Name "installTimeoutMinutes" -Default 20)
        $installResult = Invoke-SafeUpgradeInstaller -Attempts $attempts -TimeoutMinutes $timeout
        $result.ExecuteCommand = $installResult.Command
        $result.ExitCode = [string]$installResult.ExitCode
        if (-not $installResult.Success) {
            $result.UpgradeResult = "失败"
            $result.FailureReason = $installResult.Message
        }

        $after = Test-AppAfterUpgrade -App $app
        $result.AfterVersion = if (-not [string]::IsNullOrWhiteSpace($after.Version)) { $after.Version } elseif ($after.Installed) { "未知" } else { "未安装" }
        Write-SafeUpgradeLog -Message "[复检] 安装状态：$($after.Installed)，版本：$($result.AfterVersion)，配置路径：$((@($after.ExistingConfigPaths) -join '；'))" -Level "INFO"

        if ($installResult.Success) {
            $result.UpgradeResult = "成功"
            $result.FailureReason = ""
            $result.Note = "安装程序执行成功；未自动恢复配置，未替换 installers"
        }

        Generate-SafeUpgradeReport -Result $result
        Show-SafeUpgradeSummary -Result $result
    } catch {
        $result.UpgradeResult = "失败"
        $result.FailureReason = "异常：$($_.Exception.Message)"
        Write-SafeUpgradeLog -Message "[错误] 安全升级失败：$($_.Exception.Message)" -Level "ERROR"
        Generate-SafeUpgradeReport -Result $result
        Show-SafeUpgradeSummary -Result $result
    }
}

function Write-InstallLocationLog {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS", "DEBUG")][string]$Level = "INFO",
        [switch]$NoConsole
    )

    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[{0}] [{1}] {2}" -f $time, $Level, $Message

    if (-not [string]::IsNullOrWhiteSpace($Script:InstallLocationPreviewLogPath)) {
        try {
            Add-Content -LiteralPath $Script:InstallLocationPreviewLogPath -Value $line -Encoding UTF8
        } catch {
            Write-Host "[安装位置日志错误] 无法写入日志：$($_.Exception.Message)" -ForegroundColor Red
        }
    }

    if (-not $NoConsole) {
        switch ($Level) {
            "WARN"    { Write-Host $Message -ForegroundColor Yellow }
            "ERROR"   { Write-Host $Message -ForegroundColor Red }
            "SUCCESS" { Write-Host $Message -ForegroundColor Green }
            "DEBUG"   { Write-Host $Message -ForegroundColor DarkGray }
            default   { Write-Host $Message }
        }
    }
}

function Get-InstallLocationPolicy {
    param([object]$Config)

    $settings = Get-ConfigValue -Object $Config -Name "settings" -Default $null
    $policy = Get-ConfigValue -Object $settings -Name "installLocationPolicy" -Default $null

    $enabled = Get-BoolConfig -Object $policy -Name "enabled" -Default $true
    $preferCustomDir = Get-BoolConfig -Object $policy -Name "preferCustomDir" -Default $true
    $fallbackToDefault = Get-BoolConfig -Object $policy -Name "fallbackToDefault" -Default $true
    $createInstallRootIfMissing = Get-BoolConfig -Object $policy -Name "createInstallRootIfMissing" -Default $false
    $previewOnly = Get-BoolConfig -Object $policy -Name "previewOnly" -Default $true

    $defaultInstallRoot = [string](Get-ConfigValue -Object $policy -Name "defaultInstallRoot" -Default "D:\AI-Environment-Apps")
    $minSystemDriveFreeGB = [double](Get-ConfigValue -Object $policy -Name "minSystemDriveFreeGB" -Default 20)
    $warnIfSystemDriveFreeBelowGB = [double](Get-ConfigValue -Object $policy -Name "warnIfSystemDriveFreeBelowGB" -Default 30)

    return [PSCustomObject]@{
        Enabled = $enabled
        PreferCustomDir = $preferCustomDir
        DefaultInstallRoot = [Environment]::ExpandEnvironmentVariables($defaultInstallRoot)
        FallbackToDefault = $fallbackToDefault
        MinSystemDriveFreeGB = $minSystemDriveFreeGB
        WarnIfSystemDriveFreeBelowGB = $warnIfSystemDriveFreeBelowGB
        CreateInstallRootIfMissing = $createInstallRootIfMissing
        PreviewOnly = $previewOnly
    }
}

function Get-DriveSpaceInfo {
    param([Parameter(Mandatory = $true)][string]$DriveLetter)

    $name = $DriveLetter.Trim().TrimEnd(":").TrimEnd("\")
    if ([string]::IsNullOrWhiteSpace($name)) {
        return [PSCustomObject]@{
            Name = $DriveLetter
            Root = ""
            Exists = $false
            IsReady = $false
            TotalBytes = $null
            FreeBytes = $null
            TotalText = "未知"
            FreeText = "未知"
            Error = "盘符为空"
        }
    }

    try {
        $drive = New-Object System.IO.DriveInfo($name)
        $root = $drive.RootDirectory.FullName
        if (-not $drive.IsReady) {
            return [PSCustomObject]@{
                Name = $name
                Root = $root
                Exists = $true
                IsReady = $false
                TotalBytes = $null
                FreeBytes = $null
                TotalText = "未知"
                FreeText = "未知"
                Error = "磁盘未就绪"
            }
        }

        return [PSCustomObject]@{
            Name = $name
            Root = $root
            Exists = $true
            IsReady = $true
            TotalBytes = [double]$drive.TotalSize
            FreeBytes = [double]$drive.AvailableFreeSpace
            TotalText = ConvertTo-SizeText -Bytes ([double]$drive.TotalSize)
            FreeText = ConvertTo-SizeText -Bytes ([double]$drive.AvailableFreeSpace)
            Error = ""
        }
    } catch {
        return [PSCustomObject]@{
            Name = $name
            Root = ("{0}:\" -f $name)
            Exists = $false
            IsReady = $false
            TotalBytes = $null
            FreeBytes = $null
            TotalText = "未知"
            FreeText = "未知"
            Error = $_.Exception.Message
        }
    }
}

function Test-CustomInstallRoot {
    param([Parameter(Mandatory = $true)][string]$Path)

    $expandedPath = [Environment]::ExpandEnvironmentVariables($Path)
    $exists = $false
    $isDirectory = $false

    if (-not [string]::IsNullOrWhiteSpace($expandedPath) -and (Test-Path -LiteralPath $expandedPath)) {
        $exists = $true
        try {
            $item = Get-Item -LiteralPath $expandedPath -ErrorAction Stop
            $isDirectory = $item.PSIsContainer
        } catch {
            $isDirectory = $false
        }
    }

    return [PSCustomObject]@{
        Path = $expandedPath
        Exists = $exists
        IsDirectory = $isDirectory
    }
}

function Get-CurrentInstallPath {
    param(
        [object]$App,
        [object]$Detection
    )

    $detectedPath = [string](Get-ConfigValue -Object $Detection -Name "InstallPath" -Default "")
    if (-not [string]::IsNullOrWhiteSpace($detectedPath)) {
        return ([Environment]::ExpandEnvironmentVariables($detectedPath)).Trim('"')
    }

    $existingPath = Get-FirstExistingInstallPath -App $App
    if (-not [string]::IsNullOrWhiteSpace($existingPath)) {
        return $existingPath.Trim('"')
    }

    return ""
}

function Get-AppInstallLocationPlan {
    param(
        [object]$App,
        [object]$Policy,
        [object]$CustomRoot,
        [object]$SystemDrive,
        [object]$DataDrive
    )

    $name = [string](Get-ConfigValue -Object $App -Name "name" -Default "未命名软件")
    Write-InstallLocationLog -Message "[检查] $name 当前安装状态和安装位置策略" -Level "INFO"

    $detection = Test-AppInstalled -App $App
    $currentPath = Get-CurrentInstallPath -App $App -Detection $detection
    $currentStatus = if ($detection.Installed) {
        if ($detection.VersionKnown) { "已安装" } else { "已安装，版本未知" }
    } else {
        "未安装"
    }

    $supportValue = Get-ConfigValue -Object $App -Name "supportCustomInstallDir" -Default $null
    $supportText = "未知"
    $supportsCustom = $false
    if ($null -ne $supportValue) {
        $supportsCustom = Get-BoolConfig -Object $App -Name "supportCustomInstallDir" -Default $false
        $supportText = if ($supportsCustom) { "是" } else { "否" }
    }

    $customDir = [string](Get-ConfigValue -Object $App -Name "customInstallDir" -Default "")
    $customDir = [Environment]::ExpandEnvironmentVariables($customDir)
    $argsTemplate = [string](Get-ConfigValue -Object $App -Name "installDirArgsTemplate" -Default "")
    $risk = [string](Get-ConfigValue -Object $App -Name "installLocationRisk" -Default "medium")
    $appPolicy = [string](Get-ConfigValue -Object $App -Name "installLocationPolicy" -Default "manual_confirm")
    $notes = [string](Get-ConfigValue -Object $App -Name "installLocationNotes" -Default "")
    $installable = Get-Installable -App $App

    $suggestedDir = if ([string]::IsNullOrWhiteSpace($customDir)) { "-" } else { $customDir }
    $action = "人工确认"
    $extraNotes = New-Object System.Collections.Generic.List[string]

    if (-not $Policy.Enabled) {
        $action = "策略未启用"
        $extraNotes.Add("全局安装位置策略未启用") | Out-Null
    } elseif (-not $Policy.PreviewOnly) {
        $extraNotes.Add("当前配置 previewOnly 不是 true，请先确认配置") | Out-Null
    }

    if (-not $installable) {
        $action = "随依赖处理"
        $suggestedDir = "-"
        $extraNotes.Add("该组件不独立安装") | Out-Null
    } elseif ($appPolicy -eq "prefer_custom" -and $supportsCustom -and $Policy.PreferCustomDir) {
        $action = "新装时可用 D 盘"
        if (-not $DataDrive.Exists -or -not $DataDrive.IsReady) {
            $action = if ($Policy.FallbackToDefault) { "D 盘不可用，回退默认" } else { "D 盘不可用，暂停处理" }
            $extraNotes.Add("D 盘不存在或未就绪") | Out-Null
        } elseif (-not $CustomRoot.Exists) {
            $action = "先手动创建目录"
            $extraNotes.Add("默认安装根目录不存在，本阶段不会自动创建") | Out-Null
        }

        if ([string]::IsNullOrWhiteSpace($argsTemplate)) {
            $extraNotes.Add("安装器自定义目录参数未知，需人工确认") | Out-Null
        }
    } elseif ($appPolicy -eq "default_only" -or $appPolicy -eq "default") {
        $action = "保持默认"
        $suggestedDir = "-"
    } elseif ($appPolicy -eq "manual_confirm") {
        $action = "人工确认"
        if (-not $supportsCustom) {
            $suggestedDir = "-"
        }
    } else {
        $action = "人工确认"
        $extraNotes.Add("未知安装位置策略：$appPolicy") | Out-Null
    }

    if ($detection.Installed) {
        $extraNotes.Add("已安装软件不移动，只给后续新装/重装建议") | Out-Null
    }

    if ($null -ne $SystemDrive.FreeBytes) {
        $systemFreeGB = $SystemDrive.FreeBytes / 1GB
        if ($systemFreeGB -lt $Policy.MinSystemDriveFreeGB) {
            $extraNotes.Add("C 盘剩余空间低于高风险阈值") | Out-Null
        } elseif ($systemFreeGB -lt $Policy.WarnIfSystemDriveFreeBelowGB) {
            $extraNotes.Add("C 盘剩余空间低于警告阈值") | Out-Null
        }
    }

    if ($extraNotes.Count -gt 0) {
        $notes = (@($notes) + @($extraNotes)) -join "；"
    }

    Write-InstallLocationLog -Message "[结果] $name：状态=$currentStatus，当前路径=$currentPath，建议目录=$suggestedDir，动作=$action，风险=$risk" -Level "INFO"

    return [PSCustomObject]@{
        Name = $name
        CurrentStatus = $currentStatus
        CurrentPath = if ([string]::IsNullOrWhiteSpace($currentPath)) { "-" } else { $currentPath }
        SupportCustomInstallDir = $supportText
        SuggestedInstallDir = $suggestedDir
        InstallDirArgsTemplate = if ([string]::IsNullOrWhiteSpace($argsTemplate)) { "-" } else { $argsTemplate }
        Risk = $risk
        SuggestedAction = $action
        Notes = if ([string]::IsNullOrWhiteSpace($notes)) { "-" } else { $notes }
    }
}

function Generate-InstallLocationPreviewReport {
    param(
        [object[]]$Plans,
        [object]$Policy,
        [object]$SystemDrive,
        [object]$DataDrive,
        [object]$CustomRoot
    )

    $info = Get-SystemInfo
    $lines = New-Object System.Collections.Generic.List[string]

    $systemRisk = "正常"
    if ($null -eq $SystemDrive.FreeBytes) {
        $systemRisk = "未知"
    } else {
        $systemFreeGB = $SystemDrive.FreeBytes / 1GB
        if ($systemFreeGB -lt $Policy.MinSystemDriveFreeGB) {
            $systemRisk = "高风险"
        } elseif ($systemFreeGB -lt $Policy.WarnIfSystemDriveFreeBelowGB) {
            $systemRisk = "警告"
        }
    }

    $lines.Add("# 安装位置策略预览报告") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("运行时间：$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))") | Out-Null
    $lines.Add("电脑名称：$($info.ComputerName)") | Out-Null
    $lines.Add("当前用户：$($info.UserName)") | Out-Null
    $lines.Add("Windows 版本：$($info.WindowsVersion)") | Out-Null
    $lines.Add("是否管理员权限：$(if ($info.IsAdmin) { '是' } else { '否' })") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("## 磁盘与全局策略") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("- C 盘总容量：$($SystemDrive.TotalText)") | Out-Null
    $lines.Add("- C 盘剩余容量：$($SystemDrive.FreeText)") | Out-Null
    $lines.Add("- C 盘空间状态：$systemRisk") | Out-Null
    $lines.Add("- D 盘是否存在：$(if ($DataDrive.Exists -and $DataDrive.IsReady) { '是' } else { '否' })") | Out-Null
    $lines.Add("- D 盘总容量：$($DataDrive.TotalText)") | Out-Null
    $lines.Add("- D 盘剩余容量：$($DataDrive.FreeText)") | Out-Null
    $lines.Add("- 默认安装根目录：$($Policy.DefaultInstallRoot)") | Out-Null
    $lines.Add("- 默认安装根目录是否存在：$(if ($CustomRoot.Exists -and $CustomRoot.IsDirectory) { '是' } else { '否' })") | Out-Null
    $lines.Add("- 是否只预览：$(if ($Policy.PreviewOnly) { '是' } else { '否' })") | Out-Null
    $lines.Add("- 是否自动创建目录：$(if ($Policy.CreateInstallRootIfMissing) { '是' } else { '否' })") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("## 软件安装位置策略") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("| 软件 | 当前状态 | 当前路径 | 支持自定义目录 | 建议目录 | 参数模板 | 风险 | 建议动作 | 备注 |") | Out-Null
    $lines.Add("| --- | --- | --- | --- | --- | --- | --- | --- | --- |") | Out-Null

    foreach ($plan in $Plans) {
        $lines.Add((
            "| {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7} | {8} |" -f
            (Escape-MarkdownCell $plan.Name),
            (Escape-MarkdownCell $plan.CurrentStatus),
            (Escape-MarkdownCell $plan.CurrentPath),
            (Escape-MarkdownCell $plan.SupportCustomInstallDir),
            (Escape-MarkdownCell $plan.SuggestedInstallDir),
            (Escape-MarkdownCell $plan.InstallDirArgsTemplate),
            (Escape-MarkdownCell $plan.Risk),
            (Escape-MarkdownCell $plan.SuggestedAction),
            (Escape-MarkdownCell $plan.Notes)
        )) | Out-Null
    }

    Set-Content -LiteralPath $Script:InstallLocationPreviewReportPath -Value $lines -Encoding UTF8
    Write-InstallLocationLog -Message "[报告] 已生成：$Script:InstallLocationPreviewReportPath" -Level "SUCCESS"
    return $Script:InstallLocationPreviewReportPath
}

function Run-InstallLocationPreview {
    $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $Script:InstallLocationPreviewLogPath = Join-Path $Script:LogsDir ("install_location_preview_{0}.log" -f $stamp)
    $Script:InstallLocationPreviewReportPath = Join-Path $Script:ReportsDir ("install_location_preview_{0}.md" -f $stamp)

    Write-InstallLocationLog -Message "[开始] 安装位置策略预览" -Level "INFO"
    Write-InstallLocationLog -Message "[配置] 读取 config.json：$Script:ConfigPath" -Level "INFO"
    $config = Load-Config
    $policy = Get-InstallLocationPolicy -Config $config
    Write-InstallLocationLog -Message "[配置] 默认安装根目录：$($policy.DefaultInstallRoot)，只预览：$($policy.PreviewOnly)，自动创建目录：$($policy.CreateInstallRootIfMissing)" -Level "INFO"

    $systemDrive = Get-DriveSpaceInfo -DriveLetter "C"
    $dataDrive = Get-DriveSpaceInfo -DriveLetter "D"
    $customRoot = Test-CustomInstallRoot -Path $policy.DefaultInstallRoot

    Write-InstallLocationLog -Message "[磁盘] C 盘：存在=$($systemDrive.Exists)，总容量=$($systemDrive.TotalText)，剩余=$($systemDrive.FreeText)" -Level "INFO"
    Write-InstallLocationLog -Message "[磁盘] D 盘：存在=$($dataDrive.Exists)，就绪=$($dataDrive.IsReady)，总容量=$($dataDrive.TotalText)，剩余=$($dataDrive.FreeText)" -Level "INFO"
    Write-InstallLocationLog -Message "[目录] 默认安装根目录存在=$($customRoot.Exists)，路径=$($customRoot.Path)" -Level "INFO"

    $plans = @()
    $apps = @($config.apps | Where-Object { Get-BoolConfig -Object $_ -Name "enabled" -Default $true })
    foreach ($app in $apps) {
        $plans += Get-AppInstallLocationPlan -App $app -Policy $policy -CustomRoot $customRoot -SystemDrive $systemDrive -DataDrive $dataDrive
    }

    Generate-InstallLocationPreviewReport -Plans $plans -Policy $policy -SystemDrive $systemDrive -DataDrive $dataDrive -CustomRoot $customRoot | Out-Null

    Write-Host ""
    Write-Host "========================================="
    Write-Host "安装位置策略预览完成"
    Write-Host "========================================="
    Write-Host ""
    Write-Host "C 盘剩余容量：$($systemDrive.FreeText)"
    Write-Host "D 盘是否存在：$(if ($dataDrive.Exists -and $dataDrive.IsReady) { '是' } else { '否' })"
    Write-Host "D 盘剩余容量：$($dataDrive.FreeText)"
    Write-Host "默认安装根目录：$($policy.DefaultInstallRoot)"
    Write-Host "默认安装根目录是否存在：$(if ($customRoot.Exists -and $customRoot.IsDirectory) { '是' } else { '否' })"
    Write-Host ""
    Write-Host "报告路径："
    Write-Host $Script:InstallLocationPreviewReportPath
    Write-Host ""
    Write-Host "日志路径："
    Write-Host $Script:InstallLocationPreviewLogPath
    Write-Host ""

    Write-InstallLocationLog -Message "[完成] 安装位置策略预览完成" -Level "SUCCESS"
}

function Write-InstallCommandLog {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS", "DEBUG")][string]$Level = "INFO",
        [switch]$NoConsole
    )

    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[{0}] [{1}] {2}" -f $time, $Level, $Message

    if (-not [string]::IsNullOrWhiteSpace($Script:InstallCommandPreviewLogPath)) {
        try {
            Add-Content -LiteralPath $Script:InstallCommandPreviewLogPath -Value $line -Encoding UTF8
        } catch {
            Write-Host "[安装命令预演日志错误] 无法写入日志：$($_.Exception.Message)" -ForegroundColor Red
        }
    }

    if (-not $NoConsole) {
        switch ($Level) {
            "WARN"    { Write-Host $Message -ForegroundColor Yellow }
            "ERROR"   { Write-Host $Message -ForegroundColor Red }
            "SUCCESS" { Write-Host $Message -ForegroundColor Green }
            "DEBUG"   { Write-Host $Message -ForegroundColor DarkGray }
            default   { Write-Host $Message }
        }
    }
}

function Get-InstallerPackageInfo {
    param([object]$App)

    $installerName = [string](Get-ConfigValue -Object $App -Name "installer" -Default "")
    $type = ([string](Get-ConfigValue -Object $App -Name "type" -Default "exe")).ToLowerInvariant()
    $installable = Get-Installable -App $App
    $relativePath = if ([string]::IsNullOrWhiteSpace($installerName)) { "" } else { "installers\$installerName" }
    $fullPath = if ([string]::IsNullOrWhiteSpace($installerName)) { "" } else { Join-Path $Script:InstallersDir $installerName }
    $exists = (-not [string]::IsNullOrWhiteSpace($fullPath) -and (Test-Path -LiteralPath $fullPath))

    return [PSCustomObject]@{
        InstallerName = $installerName
        Type = $type
        Installable = $installable
        RelativePath = $relativePath
        FullPath = $fullPath
        Exists = $exists
    }
}

function Build-InstallCommandPreview {
    param(
        [object]$App,
        [object]$Policy
    )

    $name = [string](Get-ConfigValue -Object $App -Name "name" -Default "未命名软件")
    Write-InstallCommandLog -Message "[检查] $name 安装包和命令预演配置" -Level "INFO"

    $package = Get-InstallerPackageInfo -App $App
    $detection = Test-AppInstalled -App $App
    $currentStatus = if ($detection.Installed) {
        if ($detection.VersionKnown) { "已安装" } else { "已安装，版本未知" }
    } else {
        "未安装"
    }

    $supportValue = Get-ConfigValue -Object $App -Name "supportCustomInstallDir" -Default $null
    $supportText = "未知"
    $supportsCustom = $false
    if ($null -ne $supportValue) {
        $supportsCustom = Get-BoolConfig -Object $App -Name "supportCustomInstallDir" -Default $false
        $supportText = if ($supportsCustom) { "是" } else { "否" }
    }

    $customDir = [Environment]::ExpandEnvironmentVariables([string](Get-ConfigValue -Object $App -Name "customInstallDir" -Default ""))
    $silentArgs = @(ConvertTo-StringArray (Get-ConfigValue -Object $App -Name "silentArgs" -Default @()))
    $dirArgsTemplate = [string](Get-ConfigValue -Object $App -Name "installDirArgsTemplate" -Default "")
    $dirArgs = ""
    if ($supportsCustom -and -not [string]::IsNullOrWhiteSpace($customDir) -and -not [string]::IsNullOrWhiteSpace($dirArgsTemplate)) {
        $dirArgs = $dirArgsTemplate.Replace("{InstallDir}", $customDir)
    }

    $risk = [string](Get-ConfigValue -Object $App -Name "installLocationRisk" -Default "medium")
    $locationPolicy = [string](Get-ConfigValue -Object $App -Name "installLocationPolicy" -Default "manual_confirm")
    $locationNotes = [string](Get-ConfigValue -Object $App -Name "installLocationNotes" -Default "")
    $managedBy = [string](Get-ConfigValue -Object $App -Name "managedBy" -Default "")
    $installerKind = [string](Get-ConfigValue -Object $App -Name "installerKind" -Default "")
    $offlineInstallSupportedValue = Get-ConfigValue -Object $App -Name "offlineInstallSupported" -Default $null
    $requiresNetworkValue = Get-ConfigValue -Object $App -Name "requiresNetwork" -Default $null
    $isOnlineStub = Test-OnlineStubInstaller -App $App
    $notes = New-Object System.Collections.Generic.List[string]

    if (-not [string]::IsNullOrWhiteSpace($locationNotes)) {
        $notes.Add($locationNotes) | Out-Null
    }
    if (-not $package.Installable) {
        $message = if ([string]::IsNullOrWhiteSpace($managedBy)) { "未配置独立安装包" } else { "随 $managedBy 安装，不单独安装" }
        $notes.Add($message) | Out-Null
    }
    if (-not $package.Exists -and $package.Installable) {
        $notes.Add("安装包不存在，仅预演配置中的命令字符串") | Out-Null
    }
    if ($detection.Installed) {
        $notes.Add("已安装软件不执行安装，仅预演未来命令") | Out-Null
    }
    if (-not $Policy.PreviewOnly) {
        $notes.Add("全局策略 previewOnly 不是 true，请先确认配置") | Out-Null
    }
    if ($isOnlineStub) {
        $notes.Add("安装包存在，但疑似在线引导安装器，不保证离线安装成功，建议人工确认。") | Out-Null
    }
    if (-not [string]::IsNullOrWhiteSpace((Get-ManualInstallReason -App $App)) -and -not $isOnlineStub) {
        $notes.Add("仅供参考，不建议自动静默安装。") | Out-Null
    }

    $primarySilentArg = ""
    if ($package.Type -eq "msi") {
        if ($silentArgs.Count -gt 0) {
            $primarySilentArg = [string]$silentArgs[0]
        } else {
            $primarySilentArg = "/qn /norestart"
            $notes.Add("MSI 未配置 silentArgs，预演使用默认 /qn /norestart") | Out-Null
        }
    } elseif ($silentArgs.Count -gt 0) {
        $primarySilentArg = [string]$silentArgs[0]
    }

    $command = ""
    $manualConfirm = $false

    if (-not $package.Installable) {
        $command = "不适用：该软件不独立安装"
        $manualConfirm = $true
    } elseif ([string]::IsNullOrWhiteSpace($primarySilentArg)) {
        $command = "未知，需人工确认安装参数"
        $manualConfirm = $true
        $notes.Add("silentArgs 为空，无法生成静默安装命令") | Out-Null
        Write-InstallCommandLog -Message "[参数未知] $name silentArgs 为空，无法生成完整命令" -Level "WARN"
    } elseif ($package.Type -eq "msi") {
        $argParts = @()
        if (-not [string]::IsNullOrWhiteSpace($dirArgs)) {
            $argParts += $dirArgs
        } elseif ($supportsCustom -and -not [string]::IsNullOrWhiteSpace($customDir) -and $locationPolicy -eq "prefer_custom") {
            $notes.Add("支持自定义目录但 installDirArgsTemplate 为空，预演不加入安装目录参数") | Out-Null
            $manualConfirm = $true
        }
        $argParts += $primarySilentArg
        $command = "msiexec /i `"$($package.RelativePath)`" $($argParts -join ' ')"
    } else {
        $argForExe = $primarySilentArg
        if (-not [string]::IsNullOrWhiteSpace($dirArgs)) {
            $argForExe = $dirArgs
        } elseif ($supportsCustom -and -not [string]::IsNullOrWhiteSpace($customDir) -and $locationPolicy -eq "prefer_custom") {
            $notes.Add("支持自定义目录但 installDirArgsTemplate 为空，预演仅使用静默参数") | Out-Null
            $manualConfirm = $true
        }
        $command = "`"$($package.RelativePath)`" $argForExe"
    }

    if ($isOnlineStub) {
        $manualConfirm = $true
    }
    if (-not [string]::IsNullOrWhiteSpace((Get-ManualInstallReason -App $App))) {
        $manualConfirm = $true
    }
    if ($risk -eq "high" -or $locationPolicy -eq "manual_confirm") {
        $manualConfirm = $true
    }

    $noteText = if ($notes.Count -eq 0) { "-" } else { (@($notes) -join "；") }
    $packageExistsText = if ($package.Exists) { "是" } else { "否" }
    $installerFileText = if ([string]::IsNullOrWhiteSpace($package.InstallerName)) { "-" } else { $package.InstallerName }
    $installerKindText = if ([string]::IsNullOrWhiteSpace($installerKind)) { "未知" } else { $installerKind }
    $offlineInstallSupportedText = if ($null -eq $offlineInstallSupportedValue) { "未知" } elseif (Get-BoolConfig -Object $App -Name "offlineInstallSupported" -Default $false) { "是" } else { "否" }
    $requiresNetworkText = if ($null -eq $requiresNetworkValue) { "未知" } elseif (Get-BoolConfig -Object $App -Name "requiresNetwork" -Default $false) { "是" } else { "否" }
    $allowAutoInstall = Get-BoolConfig -Object $App -Name "autoInstallEnabled" -Default $true
    $manualReasonForAutoInstall = Get-ManualInstallReason -App $App
    $allowAutoInstallText = if ($package.Installable -and $allowAutoInstall -and [string]::IsNullOrWhiteSpace($manualReasonForAutoInstall)) { "是" } else { "否" }
    $suggestedDirText = if ([string]::IsNullOrWhiteSpace($customDir)) { "-" } else { $customDir }
    $silentText = if ($silentArgs.Count -eq 0) { "-" } else { ($silentArgs -join "；") }
    $dirArgsText = if ([string]::IsNullOrWhiteSpace($dirArgs)) {
        if ($supportsCustom -and -not [string]::IsNullOrWhiteSpace($customDir) -and [string]::IsNullOrWhiteSpace($dirArgsTemplate)) {
            "未知，需人工确认"
        } else {
            "-"
        }
    } else {
        $dirArgs
    }

    Write-InstallCommandLog -Message "[结果] $name：安装包=$packageExistsText，类型=$($package.Type)，命令=$command" -Level "INFO"

    return [PSCustomObject]@{
        Name = $name
        CurrentStatus = $currentStatus
        PackageExists = $packageExistsText
        InstallerFileName = $installerFileText
        PackageType = $package.Type
        InstallerKind = $installerKindText
        OfflineInstallSupported = $offlineInstallSupportedText
        RequiresNetwork = $requiresNetworkText
        AllowAutoInstall = $allowAutoInstallText
        SupportCustomInstallDir = $supportText
        SuggestedInstallDir = $suggestedDirText
        SilentArgs = $silentText
        InstallDirArgs = $dirArgsText
        PreviewCommand = $command
        Risk = $risk
        RequireManualConfirm = if ($manualConfirm) { "是" } else { "否" }
        Notes = $noteText
    }
}

function Generate-InstallCommandPreviewReport {
    param(
        [object[]]$Results,
        [object]$Policy
    )

    $info = Get-SystemInfo
    $lines = New-Object System.Collections.Generic.List[string]

    $lines.Add("# 安装命令预演报告") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("运行时间：$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))") | Out-Null
    $lines.Add("电脑名称：$($info.ComputerName)") | Out-Null
    $lines.Add("当前用户：$($info.UserName)") | Out-Null
    $lines.Add("是否管理员权限：$(if ($info.IsAdmin) { '是' } else { '否' })") | Out-Null
    $lines.Add("installers 路径：$Script:InstallersDir") | Out-Null
    $lines.Add("默认安装根目录：$($Policy.DefaultInstallRoot)") | Out-Null
    $lines.Add("是否只预演：是") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("## 预计安装命令") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("| 软件 | 当前状态 | 安装包存在 | 安装包文件 | 类型 | installerKind | 完整离线安装 | 需要联网 | 允许首次自动安装 | 支持自定义目录 | 建议目录 | 静默参数 | 自定义目录参数 | 预计安装命令 | 风险 | 建议人工确认 | 备注 |") | Out-Null
    $lines.Add("| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |") | Out-Null

    foreach ($result in $Results) {
        $lines.Add((
            "| {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7} | {8} | {9} | {10} | {11} | {12} | {13} | {14} | {15} | {16} |" -f
            (Escape-MarkdownCell $result.Name),
            (Escape-MarkdownCell $result.CurrentStatus),
            (Escape-MarkdownCell $result.PackageExists),
            (Escape-MarkdownCell $result.InstallerFileName),
            (Escape-MarkdownCell $result.PackageType),
            (Escape-MarkdownCell $result.InstallerKind),
            (Escape-MarkdownCell $result.OfflineInstallSupported),
            (Escape-MarkdownCell $result.RequiresNetwork),
            (Escape-MarkdownCell $result.AllowAutoInstall),
            (Escape-MarkdownCell $result.SupportCustomInstallDir),
            (Escape-MarkdownCell $result.SuggestedInstallDir),
            (Escape-MarkdownCell $result.SilentArgs),
            (Escape-MarkdownCell $result.InstallDirArgs),
            (Escape-MarkdownCell $result.PreviewCommand),
            (Escape-MarkdownCell $result.Risk),
            (Escape-MarkdownCell $result.RequireManualConfirm),
            (Escape-MarkdownCell $result.Notes)
        )) | Out-Null
    }

    Set-Content -LiteralPath $Script:InstallCommandPreviewReportPath -Value $lines -Encoding UTF8
    Write-InstallCommandLog -Message "[报告] 已生成：$Script:InstallCommandPreviewReportPath" -Level "SUCCESS"
    return $Script:InstallCommandPreviewReportPath
}

function Run-InstallCommandPreview {
    $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $Script:InstallCommandPreviewLogPath = Join-Path $Script:LogsDir ("install_command_preview_{0}.log" -f $stamp)
    $Script:InstallCommandPreviewReportPath = Join-Path $Script:ReportsDir ("install_command_preview_{0}.md" -f $stamp)

    Write-InstallCommandLog -Message "[开始] 安装命令预演" -Level "INFO"
    Write-InstallCommandLog -Message "[配置] 读取 config.json：$Script:ConfigPath" -Level "INFO"
    $config = Load-Config
    $policy = Get-InstallLocationPolicy -Config $config
    Write-InstallCommandLog -Message "[配置] 默认安装根目录：$($policy.DefaultInstallRoot)，只预演=True" -Level "INFO"
    Write-InstallCommandLog -Message "[目录] 检查 installers 目录：$Script:InstallersDir，存在=$(Test-Path -LiteralPath $Script:InstallersDir)" -Level "INFO"

    $results = @()
    $apps = @($config.apps | Where-Object { Get-BoolConfig -Object $_ -Name "enabled" -Default $true })
    foreach ($app in $apps) {
        $results += Build-InstallCommandPreview -App $app -Policy $policy
    }

    Generate-InstallCommandPreviewReport -Results $results -Policy $policy | Out-Null

    Write-Host ""
    Write-Host "========================================="
    Write-Host "安装命令预演完成"
    Write-Host "========================================="
    Write-Host ""
    Write-Host "报告路径："
    Write-Host $Script:InstallCommandPreviewReportPath
    Write-Host ""
    Write-Host "日志路径："
    Write-Host $Script:InstallCommandPreviewLogPath
    Write-Host ""

    Write-InstallCommandLog -Message "[完成] 安装命令预演完成" -Level "SUCCESS"
}

function Pause-ForUser {
    Write-Host ""
    Read-Host "按 Enter 返回菜单"
}

function Show-Menu {
    while ($true) {
        Clear-Host
        Write-Host "========================================="
        Write-Host "AI 开发环境初始化工具 v2.5.3"
        Write-Host "========================================="
        Write-Host ""
        Write-Host "请选择操作："
        Write-Host ""
        Write-Host "[1] 一键安装 / 升级所有软件（推荐）"
        Write-Host "[2] 仅检查电脑环境"
        Write-Host "[3] 导出环境报告"
        Write-Host "[4] 修复环境变量"
        Write-Host "[5] 检查可更新软件"
        Write-Host "[6] 下载最新版安装包"
        Write-Host "[7] 备份软件配置"
        Write-Host "[8] 恢复软件配置"
        Write-Host "[9] 安全升级模式"
        Write-Host "[10] 安装位置策略预览"
        Write-Host "[11] 安装命令预演"
        Write-Host "[12] 退出"
        Write-Host ""

        $choice = Read-Host "请输入序号"

        try {
            switch ($choice) {
                "1" {
                    Run-InstallOrUpgrade
                    Pause-ForUser
                }
                "2" {
                    Run-CheckOnly
                    Pause-ForUser
                }
                "3" {
                    Export-CurrentReport
                    Pause-ForUser
                }
                "4" {
                    Run-RepairEnvironment
                    Pause-ForUser
                }
                "5" {
                    Run-UpdateCheckOnly
                    Pause-ForUser
                }
                "6" {
                    Run-DownloadLatestInstallers
                    Pause-ForUser
                }
                "7" {
                    Run-ConfigBackup
                    Pause-ForUser
                }
                "8" {
                    Run-ConfigRestore
                    Pause-ForUser
                }
                "9" {
                    Run-SafeUpgradeMode
                    Pause-ForUser
                }
                "10" {
                    Run-InstallLocationPreview
                    Pause-ForUser
                }
                "11" {
                    Run-InstallCommandPreview
                    Pause-ForUser
                }
                "12" {
                    Write-Log -Message "[退出] 用户选择退出。" -Level "INFO"
                    return
                }
                default {
                    Write-Host "输入无效，请输入 1 到 12。" -ForegroundColor Yellow
                    Start-Sleep -Seconds 1
                }
            }
        } catch {
            Write-Log -Message "[错误] 操作失败：$($_.Exception.Message)" -Level "ERROR"
            Generate-Report -Results $Script:LastResults -OperationName "异常处理" | Out-Null
            Pause-ForUser
        }
    }
}

try {
    Write-Log -Message "[启动] AI 开发环境初始化工具，路径：$Script:BaseDir" -Level "INFO" -NoConsole
    if ($env:AI_ENV_SKIP_ENTRY -eq "1") {
        return
    }
    Ensure-Admin
    Show-Menu
    exit 0
} catch {
    Write-Log -Message "[严重错误] $($_.Exception.Message)" -Level "ERROR"
    try {
        Generate-Report -Results $Script:LastResults -OperationName "异常退出" | Out-Null
    } catch {
        Write-Host "[错误] 生成异常报告失败：$($_.Exception.Message)" -ForegroundColor Red
    }
    exit 1
}


