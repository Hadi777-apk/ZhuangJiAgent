# AI 开发环境初始化工具 GUI v2.5.3
# PowerShell WPF GUI — 零依赖
param([switch]$SkipAdminCheck)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase

# Admin check
if (-not $SkipAdminCheck) {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Start-Process -FilePath (Get-Process -Id $PID).Path -ArgumentList "-NoProfile -EP Bypass -File `"$PSCommandPath`" -SkipAdminCheck" -Verb RunAs
        exit
    }
}

# Paths
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Cf = Join-Path $ScriptDir "config.json"
$Uc = Join-Path $ScriptDir "update-config.json"
$Idir = Join-Path $ScriptDir "installers"
$Bdir = Join-Path $ScriptDir "backups"
$Rdir = Join-Path $ScriptDir "reports"

foreach ($d in @($Idir, $Bdir, $Rdir)) { if (!(Test-Path $d)) { mkdir $d -Force | Out-Null } }

function Load-Json($Path) { if (Test-Path $Path) { try { return Get-Content $Path -Raw -Encoding UTF8 | ConvertFrom-Json } catch {} } return $null }
$Global:Cfg = Load-Json $Cf
$Global:Upd = Load-Json $Uc
$br = New-Object System.Windows.Media.BrushConverter

# ============================================================================
# Helpers
# ============================================================================
$br = New-Object System.Windows.Media.BrushConverter
$script:Elements = @{}  # Global UI element registry (avoids closure issues)
function b($h) { return $br.ConvertFromString($h) }

function L($t, $fs=13, $c="#1a2332", $fw="Normal") {
    $tb = New-Object Windows.Controls.TextBlock
    $tb.Text = $t; $tb.FontSize = $fs; $tb.FontWeight = $fw
    $tb.Foreground = b $c; $tb.TextWrapping = [System.Windows.TextWrapping]::Wrap
    return $tb
}

function Card {
    $border = New-Object Windows.Controls.Border
    $border.Background = b "#fff"; $border.BorderBrush = b "#c8d4e0"
    $border.BorderThickness = [System.Windows.Thickness]::new(1)
    $border.CornerRadius = [System.Windows.CornerRadius]::new(8)
    $border.Padding = [System.Windows.Thickness]::new(18)
    $border.Margin = [System.Windows.Thickness]::new(0,0,0,12)
    $sp = New-Object Windows.Controls.StackPanel
    $border.Child = $sp
    return @{ border=$border; stack=$sp }
}

function CardTitle($t) {
    $tb = L $t 14 "#0d3b7a" "SemiBold"
    $tb.Margin = [System.Windows.Thickness]::new(0,0,0,10)
    return $tb
}

function Badge($t, $color="green") {
    $bg = @{green="#e6f7f5";yellow="#fef3c7";red="#fef2f2"}[$color]
    $fg = @{green="#0d9488";yellow="#d97706";red="#dc2626"}[$color]
    $border = New-Object Windows.Controls.Border
    $border.CornerRadius = [System.Windows.CornerRadius]::new(10)
    $border.Padding = [System.Windows.Thickness]::new(8,3,8,3)
    $border.Background = b $bg
    $tb = L $t 10 $fg "SemiBold"
    $border.Child = $tb
    return $border
}

function SwRow($name, $status, $badgeText, $badgeColor) {
    $grid = New-Object Windows.Controls.Grid
    $grid.Margin = [System.Windows.Thickness]::new(0,0,0,6)
    $c1 = New-Object Windows.Controls.ColumnDefinition; $c1.Width = [System.Windows.GridLength]::new(1,[System.Windows.GridUnitType]::Star)
    $c2 = New-Object Windows.Controls.ColumnDefinition; $c2.Width = [System.Windows.GridLength]::Auto
    $grid.ColumnDefinitions.Add($c1); $grid.ColumnDefinitions.Add($c2)

    $bg = New-Object Windows.Controls.Border
    $bg.Background = b "#f0f4f8"; $bg.CornerRadius = [System.Windows.CornerRadius]::new(6)
    $bg.Padding = [System.Windows.Thickness]::new(12,8,12,8)
    [Windows.Controls.Grid]::SetColumnSpan($bg,2); $grid.Children.Add($bg)|Out-Null

    $nm = L $name 12.5 "#1a2332" "Medium"
    $nm.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    [Windows.Controls.Grid]::SetColumn($nm,0); $grid.Children.Add($nm)|Out-Null

    $st = New-Object Windows.Controls.StackPanel
    $st.Orientation = [System.Windows.Controls.Orientation]::Horizontal
    $st.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    if ($badgeText) { $st.Children.Add((Badge $badgeText $badgeColor))|Out-Null }
    $stb = L $status 11 "#5a6d80"; $stb.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    $st.Children.Add($stb)|Out-Null
    [Windows.Controls.Grid]::SetColumn($st,1); $grid.Children.Add($st)|Out-Null
    return $grid
}

function PageHeader($title, $desc) {
    $sp = New-Object Windows.Controls.StackPanel
    $sp.Margin = [System.Windows.Thickness]::new(0,0,0,14)
    $sp.Children.Add((L $title 19 "#1a2332" "SemiBold"))|Out-Null
    $sp.Children.Add((L $desc 12 "#5a6d80"))|Out-Null
    return $sp
}

function ActionBar {
    param([object[]]$Buttons)
    $sp = New-Object Windows.Controls.StackPanel
    $sp.Orientation = [System.Windows.Controls.Orientation]::Horizontal
    $sp.Margin = [System.Windows.Thickness]::new(0,6,0,0)
    foreach ($btn in $Buttons) {
        $bobj = New-Object Windows.Controls.Button
        $bobj.Content = $btn.Text; $bobj.FontSize = 12.5; $bobj.Height = 34
        $bobj.Padding = [System.Windows.Thickness]::new(18,0,18,0)
        $bobj.Cursor = [System.Windows.Input.Cursors]::Hand
        $bobj.Margin = [System.Windows.Thickness]::new(0,0,6,0)
        $bobj.BorderThickness = [System.Windows.Thickness]::new(1)
        if ($btn.Style -eq "primary") {
            $bobj.Background = b "#1a73e8"; $bobj.Foreground = b "#fff"; $bobj.BorderBrush = b "#1a73e8"
            $bobj.FontWeight = "SemiBold"
        } elseif ($btn.Style -eq "outline") {
            $bobj.Background = b "#fff"; $bobj.Foreground = b "#1557b0"; $bobj.BorderBrush = b "#1a73e8"
        } elseif ($btn.Style -eq "success") {
            $bobj.Background = b "#0d9488"; $bobj.Foreground = b "#fff"; $bobj.BorderBrush = b "#0d9488"
            $bobj.FontWeight = "SemiBold"
        }
        if ($btn.OnClick) { $bobj.Add_Click($btn.OnClick) }
        $sp.Children.Add($bobj)|Out-Null
    }
    return $sp
}

# ============================================================================
# Detection functions
# ============================================================================
function Get-SW {
    $r = @()
    if (-not $Global:Cfg) { return $r }
    foreach ($a in $Global:Cfg) {
        if (-not $a.name) { continue }
        $ins=$false; $ver=""
        if ($a.checkCommands) { foreach ($c in $a.checkCommands) { try { $o=Invoke-Expression $c 2>&1; if ($LASTEXITCODE -eq 0 -or $o -match '\d') { $ins=$true; $ver=($o -split '\n')[0].Trim(); break } } catch {} } }
        if (-not $ins -and $a.registryNames) {
            $f = Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" 2>$null | Where-Object { $dn=$_.DisplayName; $a.registryNames | ForEach-Object { $dn -like "*$_*" } } | Select -First 1
            if ($f) { $ins=$true; $ver=$f.DisplayVersion }
        }
        if (-not $ins -and $a.installPaths) { foreach ($p in $a.installPaths) { if (Test-Path [Environment]::ExpandEnvironmentVariables($p)) { $ins=$true; $ver="已安装"; break } } }
        $ip = if($a.installer){Join-Path $Idir $a.installer}else{""}
        $rdy = ($ip -and (Test-Path $ip))
        $r += @{ Name=$a.name; Installed=$ins; Version=$ver; Ready=$rdy }
    }
    return $r
}

function Get-IL {
    $r = @()
    if (-not $Global:Cfg) { return $r }
    foreach ($a in $Global:Cfg) {
        if (-not $a.name -or -not $a.installer) { continue }
        $ip = Join-Path $Idir $a.installer
        $ex = Test-Path $ip
        $r += @{ Name=$a.name; Exists=$ex; Size=if($ex){"$([math]::Round((Get-Item $ip).Length/1MB)) MB"}else{"缺失"}; Auto=($a.autoInstallEnabled -ne $false); Stub=($a.installerKind -eq 'online_stub') }
    }
    return $r
}

# ============================================================================
# Pages
# ============================================================================

function Build-Check {
    $c = New-Object Windows.Controls.StackPanel
    $c.Children.Add((PageHeader "环境检测" "硬件信息、Windows 版本、磁盘空间、已安装软件状态"))|Out-Null

    # System info card
    $cd = Card; $cd.stack.Children.Add((CardTitle "系统概览"))|Out-Null
    $wrap = New-Object Windows.Controls.WrapPanel; $cd.stack.Children.Add($wrap)|Out-Null
    $c.Children.Add($cd.border)|Out-Null
    $script:Elements['CheckWrap'] = $wrap

    # Software status card
    $cd2 = Card; $cd2.stack.Children.Add((CardTitle "软件安装状态"))|Out-Null
    $swList = New-Object Windows.Controls.StackPanel
    $swList.Name = "SwList"
    $placeholder = L "点击「开始检测」加载..." 12 "#5a6d80"
    $swList.Children.Add($placeholder)|Out-Null
    $cd2.stack.Children.Add($swList)|Out-Null
    $c.Children.Add($cd2.border)|Out-Null
    $script:Elements['CheckSwList'] = $swList

    $c.Children.Add((ActionBar @(
        @{Text="🔍 开始检测"; Style="primary"; OnClick={
            try {
                Do-Check
            } catch { [System.Windows.MessageBox]::Show("ERROR: $_`n$($_.ScriptStackTrace)","Debug") }
        }}
        @{Text="📄 导出报告"; Style="outline"; OnClick={
            $dt=Get-Date -Format "yyyyMMdd_HHmmss"; $rp=Join-Path $Rdir "env_$dt.txt"
            $rpt="AI 开发环境 v2.5.3`n==============`n时间: $(Get-Date)`nOS: $((Get-CimInstance Win32_OperatingSystem).Caption)`nCPU: $((Get-CimInstance Win32_Processor).Name)`nRAM: $([math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/1GB)) GB`n"; $rpt|Out-File $rp -Encoding UTF8
            [System.Windows.MessageBox]::Show("报告已导出:`n$rp","完成")
        }}
    )))|Out-Null
    return $c
}

function Do-Check {
    $wrap = $script:Elements['CheckWrap']
    $swList = $script:Elements['CheckSwList']
    if (-not $wrap -or -not $swList) { return }

    $wrap.Children.Clear()
    $os = (Get-CimInstance Win32_OperatingSystem)
    $cpu = (Get-CimInstance Win32_Processor).Name -replace '\s+',' ' -replace '\(R\)|\(TM\)|CPU\s+',''
    $gpu = (Get-CimInstance Win32_VideoController|Where-Object Name -notmatch 'Microsoft Basic'|Select -First 1).Name
    $mem = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/1GB)
    $cdisk = Get-PSDrive C -EA 0; $ddisk = Get-PSDrive D -EA 0
    $admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    $items = @(
        @{l="操作系统";v="$($os.Caption) $($os.Version)"},@{l="管理员权限";v=$(if($admin){"已获取"}else{"未获取"})},
        @{l="PowerShell";v=$PSVersionTable.PSVersion.ToString()},
        @{l="CPU";v=$cpu},@{l="内存";v="$mem GB"},@{l="显卡";v=$gpu},
        @{l="C 盘可用";v=$(if($cdisk){"$([math]::Round($cdisk.Free/1GB)) GB"}else{"N/A"})},
        @{l="D 盘可用";v=$(if($ddisk){"$([math]::Round($ddisk.Free/1GB)) GB"}else{"N/A"})}
    )
    foreach ($i in $items) {
        $ib = New-Object Windows.Controls.Border
        $ib.Background = b "#f0f4f8"; $ib.CornerRadius = [System.Windows.CornerRadius]::new(6)
        $ib.Padding = [System.Windows.Thickness]::new(12); $ib.Margin = [System.Windows.Thickness]::new(0,0,8,8); $ib.Width=190
        $isp = New-Object Windows.Controls.StackPanel
        $isp.Children.Add((L $i.l 10 "#5a6d80"))|Out-Null
        $isp.Children.Add((L $i.v 13 "#1a2332" "SemiBold"))|Out-Null
        $ib.Child=$isp; $wrap.Children.Add($ib)|Out-Null
    }
    $swList.Children.Clear()
    $sw = Get-SW
    foreach ($s in $sw) {
        $c = if($s.Installed){"green"}elseif($s.Ready){"yellow"}else{"red"}
        $b = if($s.Installed){"✓ 已安装"}elseif($s.Ready){"可安装"}else{"无安装包"}
        $swList.Children.Add((SwRow $s.Name $s.Version $b $c))|Out-Null
    }
    $script:Statusbar.Text = "环境检测完成"
}

function Build-Preview {
    $c = New-Object Windows.Controls.StackPanel
    $c.Children.Add((PageHeader "安装预演" "预览安装位置、磁盘策略和安装命令（只读）"))|Out-Null

    $cd1=Card; $cd1.stack.Children.Add((CardTitle "安装位置策略"))|Out-Null
    $strat=New-Object Windows.Controls.StackPanel
    $strat.Children.Add((L "点击「执行预演」加载..." 12 "#5a6d80"))|Out-Null
    $cd1.stack.Children.Add($strat)|Out-Null; $c.Children.Add($cd1.border)|Out-Null
    $script:Elements['PreviewStrat'] = $strat

    $cd2=Card; $cd2.stack.Children.Add((CardTitle "安装命令预览"))|Out-Null
    $con=New-Object Windows.Controls.TextBox; $con.IsReadOnly=$true; $con.Background=b "#1e293b"; $con.Foreground=b "#cbd5e1"
    $con.FontFamily="Consolas"; $con.FontSize=11; $con.MinHeight=160; $con.MaxHeight=260
    $con.VerticalScrollBarVisibility="Auto"; $con.TextWrapping="Wrap"; $con.Text="点击「执行预演」生成..."
    $cd2.stack.Children.Add($con)|Out-Null; $c.Children.Add($cd2.border)|Out-Null
    $script:Elements['PreviewConsole'] = $con

    $c.Children.Add((ActionBar @(@{Text="📋 执行预演"; Style="primary"; OnClick={ Do-Preview }})))|Out-Null
    return $c
}

function Do-Preview {
    $strat = $script:Elements['PreviewStrat']
    $con = $script:Elements['PreviewConsole']
    if (-not $strat -or -not $con) { return }
    $il=Get-IL; $strat.Children.Clear(); $lines=@()
    $cf=0; try{$cd=Get-PSDrive C -EA 0; if($cd){$cf=$cd.Free/1GB}}catch{}
    foreach ($ins in $il) { if (-not $ins.Exists) { continue }
        $pref=($cf -lt 50); $loc=if($pref){"D:\\AI-Environment-Apps\\$($ins.Name)"}else{"C:\\Program Files\\$($ins.Name)"}
        $risk=if($cf -lt 30){"C盘紧张"}elseif($pref){"建议D盘"}else{"默认"}
        $rc=if($cf -lt 30){"yellow"}else{"green"}
        $strat.Children.Add((SwRow $ins.Name "→ $loc" $risk $rc))|Out-Null
        $lines+="# $($ins.Name) ($($ins.Size))`nmsiexec /i `"$($Idir -replace '\\','\\')\$($ins.Name)`" /quiet /norestart`n"
    }
    $con.Text=($lines -join "`n"); $script:Statusbar.Text="预演完成"
}

function Build-Install {
    $c=New-Object Windows.Controls.StackPanel
    $c.Children.Add((PageHeader "一键安装" "使用 installers/ 中的本地安装包批量安装软件"))|Out-Null
    $cd=Card; $cd.stack.Children.Add((CardTitle "待安装软件"))|Out-Null
    $ilist=New-Object Windows.Controls.StackPanel; $ilist.Name="InstallList"
    $cd.stack.Children.Add($ilist)|Out-Null; $c.Children.Add($cd.border)|Out-Null
    $cd2=Card; $cd2.stack.Children.Add((CardTitle "⚠️ 注意"))|Out-Null
    $cd2.stack.Children.Add((L "此操作将执行安装包，写入程序目录、注册表、环境变量。`n安装过程不可中断，预计 5-15 分钟。请确保电脑接通电源。" 12 "#5a6d80"))|Out-Null
    $c.Children.Add($cd2.border)|Out-Null

    $installers = Get-IL
    foreach ($ins in $installers) { if ($ins.Exists) {
        $lb = if($ins.Stub){"需确认"}elseif(-not $ins.Auto){"需手动确认"}else{"可安装"}
        $lc = if($ins.Stub -or -not $ins.Auto){"yellow"}else{"green"}
        $ilist.Children.Add((SwRow $ins.Name "$($ins.Size)" $lb $lc))|Out-Null
    }}
    $ready = ($installers|Where-Object Exists).Count
    $Statusbar.Text = "安装包: $ready / $($installers.Count) 就绪"

    $c.Children.Add((ActionBar @(@{Text="▶ 开始安装"; Style="success"; OnClick={
        $r= [System.Windows.MessageBox]::Show("将执行安装包，确定继续？","确认",[System.Windows.MessageBoxButton]::YesNo,[System.Windows.MessageBoxImage]::Warning)
        if ($r -eq "Yes") {
            $pi=Join-Path $ScriptDir "install.ps1"
            if (Test-Path $pi) {
                try { & $pi 2>&1 | Out-Null; [System.Windows.MessageBox]::Show("安装完成!","完成") } catch { [System.Windows.MessageBox]::Show("出错: $_","错误") }
            }
        }
    }})))|Out-Null
    return $c
}

function Build-Update {
    $c=New-Object Windows.Controls.StackPanel
    $c.Children.Add((PageHeader "更新下载" "检查可更新软件，下载最新版到 downloads/latest/"))|Out-Null
    $cd=Card; $cd.stack.Children.Add((CardTitle "软件更新状态"))|Out-Null
    $ulist=New-Object Windows.Controls.StackPanel
    $ulist.Children.Add((L "点击「检查更新」加载..." 12 "#5a6d80"))|Out-Null
    $cd.stack.Children.Add($ulist)|Out-Null; $c.Children.Add($cd.border)|Out-Null
    $script:Elements['UpdateList'] = $ulist
    $cd2=Card; $cd2.stack.Children.Add((CardTitle "下载来源"))|Out-Null
    $cd2.stack.Children.Add((L "所有下载来自 sources/allowlist.json 官方白名单，下载到 downloads/latest/。" 11 "#5a6d80"))|Out-Null
    $c.Children.Add($cd2.border)|Out-Null

    $c.Children.Add((ActionBar @(
        @{Text="🔄 检查更新"; Style="primary"; OnClick={ Do-Update }}
        @{Text="📥 下载可更新项"; Style="outline"; OnClick={ [System.Windows.MessageBox]::Show("下载功能将在后续版本完善。","提示") }}
    )))|Out-Null
    return $c
}

function Do-Update {
    $ulist = $script:Elements['UpdateList']
    if (-not $ulist) { return }
    $ulist.Children.Clear()
    if ($Global:Upd) {
        foreach ($a in $Global:Upd) {
            if (-not $a.name -or $a.enabled -eq $false) { continue }
            $cur="未知"
            if ($a.versionCommand) { try { $cur=(Invoke-Expression $a.versionCommand 2>&1|Select -First 1).Trim() } catch {} }
            $ulist.Children.Add((SwRow $a.name "当前: $cur" "已检测" "green"))|Out-Null
        }
    } else {
        $ulist.Children.Add((SwRow "update-config.json" "未找到配置文件" "错误" "red"))|Out-Null
    }
    $script:Statusbar.Text = "更新检查完成"
}

function Build-Config {
    $c=New-Object Windows.Controls.StackPanel
    $c.Children.Add((PageHeader "配置管理" "备份或恢复软件配置文件"))|Out-Null
    $cd=Card; $cd.stack.Children.Add((CardTitle "当前支持"))|Out-Null
    $cs=New-Object Windows.Controls.StackPanel; $cs.Name="ConfigSupport"
    $ocFound = ((Test-Path "$env:LOCALAPPDATA\OpenClaw") -or (Test-Path "$env:APPDATA\OpenClaw"))
    $cs.Children.Add((SwRow "OpenClaw 配置" $(if($ocFound){"已检测到"}else{"未检测到"}) $(if($ocFound){"可备份"}else{"未安装"}) $(if($ocFound){"green"}else{"yellow"})))|Out-Null
    $cd.stack.Children.Add($cs)|Out-Null; $c.Children.Add($cd.border)|Out-Null

    $cd2=Card; $cd2.stack.Children.Add((CardTitle "历史备份"))|Out-Null
    $hs=New-Object Windows.Controls.StackPanel; $hs.Name="BackupHistory"
    $cbd=Join-Path $Bdir "configs"
    if (Test-Path $cbd) { $bks=Get-ChildItem $cbd -Directory|Sort Name -Descending|Select -First 5
        foreach ($bk in $bks) { $hs.Children.Add((SwRow $bk.Name "" "备份" "green"))|Out-Null }
    }
    if ($hs.Children.Count -eq 0) { $hs.Children.Add((L "暂无备份记录" 12 "#5a6d80"))|Out-Null }
    $cd2.stack.Children.Add($hs)|Out-Null; $c.Children.Add($cd2.border)|Out-Null

    $c.Children.Add((ActionBar @(
        @{Text="💾 备份所有配置"; Style="primary"; OnClick={
            $dt=Get-Date -Format "yyyyMMdd_HHmmss"; $bd=Join-Path (Join-Path $Bdir "configs") $dt
            mkdir $bd -Force|Out-Null
            foreach ($p in @("$env:LOCALAPPDATA\OpenClaw","$env:APPDATA\OpenClaw")) { if (Test-Path $p) { Copy-Item $p $bd -Recurse -Force -EA 0; break } }
            [System.Windows.MessageBox]::Show("已备份到:`n$bd","完成")
            $Statusbar.Text="已备份"
        }}
        @{Text="📂 打开备份目录"; Style="outline"; OnClick={
            $bd=Join-Path $Bdir "configs"; if (!(Test-Path $bd)){mkdir $bd -Force|Out-Null}
            Start-Process explorer -Arg $bd
        }}
    )))|Out-Null
    return $c
}

# ============================================================================
# WPF Window
# WPF Window
# ============================================================================
$win = New-Object System.Windows.Window
$win.Title = "AI 开发环境初始化工具 v2.5.3"
$win.Width = 960; $win.Height = 680; $win.MinWidth = 760; $win.MinHeight = 520
$win.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen

$root = New-Object Windows.Controls.Grid
$r1=New-Object Windows.Controls.RowDefinition; $r1.Height=[System.Windows.GridLength]::new(44)
$r2=New-Object Windows.Controls.RowDefinition; $r2.Height=[System.Windows.GridLength]::new(1,[System.Windows.GridUnitType]::Star)
$r3=New-Object Windows.Controls.RowDefinition; $r3.Height=[System.Windows.GridLength]::new(28)
$root.RowDefinitions.Add($r1);$root.RowDefinitions.Add($r2);$root.RowDefinitions.Add($r3)
$win.Content = $root

# Title Bar
$tb = New-Object Windows.Controls.Border; $tb.Background = b "#0d3b7a"
[Windows.Controls.Grid]::SetRow($tb,0); $root.Children.Add($tb)|Out-Null
$tbsp = New-Object Windows.Controls.StackPanel; $tbsp.Orientation = "Horizontal"; $tbsp.Margin=[System.Windows.Thickness]::new(12,0,12,0)
$tb.Child = $tbsp
$tbsp.Children.Add((New-Object Windows.Controls.Border -Property @{Background=b "#fff";CornerRadius=[System.Windows.CornerRadius]::new(3);Width=20;Height=20;Margin=[System.Windows.Thickness]::new(0,0,8,0);Child=(L "AI" 11 "#0d3b7a" "Bold")}))|Out-Null
$tbsp.Children.Add((L "AI 开发环境初始化工具" 13 "#fff" "SemiBold"))|Out-Null
$tbsp.Children.Add((L "v2.5.3" 11 "#9cc4f8"))|Out-Null

# Body
$body = New-Object Windows.Controls.Grid
$bc1=New-Object Windows.Controls.ColumnDefinition; $bc1.Width=[System.Windows.GridLength]::new(200)
$bc2=New-Object Windows.Controls.ColumnDefinition; $bc2.Width=[System.Windows.GridLength]::new(1,[System.Windows.GridUnitType]::Star)
$body.ColumnDefinitions.Add($bc1);$body.ColumnDefinitions.Add($bc2)
[Windows.Controls.Grid]::SetRow($body,1);$root.Children.Add($body)|Out-Null

# Sidebar
$side = New-Object Windows.Controls.Border
$side.Background=b "#fff";$side.BorderBrush=b "#c8d4e0";$side.BorderThickness=[System.Windows.Thickness]::new(0,0,1,0)
[Windows.Controls.Grid]::SetColumn($side,0);$body.Children.Add($side)|Out-Null
$sgrid=New-Object Windows.Controls.Grid
$sr1=New-Object Windows.Controls.RowDefinition; $sr1.Height=[System.Windows.GridLength]::new(1,[System.Windows.GridUnitType]::Star)
$sr2=New-Object Windows.Controls.RowDefinition; $sr2.Height=[System.Windows.GridLength]::Auto
$sgrid.RowDefinitions.Add($sr1);$sgrid.RowDefinitions.Add($sr2)
$side.Child=$sgrid

$nav=New-Object Windows.Controls.StackPanel; $nav.Margin=[System.Windows.Thickness]::new(0,8,0,0)
[Windows.Controls.Grid]::SetRow($nav,0);$sgrid.Children.Add($nav)|Out-Null

$sft=New-Object Windows.Controls.Border; $sft.BorderBrush=b "#c8d4e0";$sft.BorderThickness=[System.Windows.Thickness]::new(0,1,0,0)
$sft.Padding=[System.Windows.Thickness]::new(12,8,12,8);$sft.Background=b "#f8fafc"
[Windows.Controls.Grid]::SetRow($sft,1);$sgrid.Children.Add($sft)|Out-Null
$sft.Child = (New-Object Windows.Controls.StackPanel)
$sft.Child.Children.Add((L "USB 离线模式" 10 "#5a6d80"))|Out-Null
$sft.Child.Children.Add((L "管理员: 已获取" 10 "#5a6d80"))|Out-Null

# Content area
$content = New-Object Windows.Controls.ScrollViewer
$content.VerticalScrollBarVisibility="Auto"
[Windows.Controls.Grid]::SetColumn($content,1);$body.Children.Add($content)|Out-Null
$cstack = New-Object Windows.Controls.StackPanel; $cstack.Margin=[System.Windows.Thickness]::new(22,18,22,18)
$content.Content = $cstack

# Status bar
$sb = New-Object Windows.Controls.Border; $sb.Background=b "#fff";$sb.BorderBrush=b "#c8d4e0";$sb.BorderThickness=[System.Windows.Thickness]::new(0,1,0,0)
[Windows.Controls.Grid]::SetRow($sb,2);$root.Children.Add($sb)|Out-Null
$sbsp = New-Object Windows.Controls.StackPanel; $sbsp.Orientation="Horizontal";$sbsp.Margin=[System.Windows.Thickness]::new(12,0,12,0)
$sb.Child=$sbsp
$sbdot = New-Object System.Windows.Shapes.Ellipse; $sbdot.Width=7;$sbdot.Height=7;$sbdot.Fill=b "#0d9488";$sbdot.Margin=[System.Windows.Thickness]::new(0,0,6,0)
$sbsp.Children.Add($sbdot)|Out-Null
$Statusbar = L "工具就绪" 10 "#5a6d80"; $sbsp.Children.Add($Statusbar)|Out-Null

# ============================================================================
# Navigation
# ============================================================================
$pages = @{Check=@();Preview=@();Install=@();Update=@();Config=@()}
$active = ""

function NavTo($name) {
    if ($active -eq $name) { return }
    $active = $name
    # Build page if not cached
    if ($pages[$name].Count -eq 0) {
        $pages[$name] = @(switch($name) {
            "Check"   { Build-Check }
            "Preview" { Build-Preview }
            "Install" { Build-Install }
            "Update"  { Build-Update }
            "Config"  { Build-Config }
        })
    }
    # Update content
    $cstack.Children.Clear()
    foreach ($el in $pages[$name]) { $cstack.Children.Add($el)|Out-Null }
    # Update nav buttons
    foreach ($b in $nav.Children) { $b.Background = b "Transparent"; $b.Foreground = b "#5a6d80"; $b.FontWeight = "Normal" }
    $btn = $nav.Children | Where-Object Tag -eq $name | Select -First 1
    if ($btn) { $btn.Background = b "#e8f0fe"; $btn.Foreground = b "#1557b0"; $btn.FontWeight = "SemiBold" }
}

function NavBtn($text, $tag, $icon) {
    $btn = New-Object Windows.Controls.Button; $btn.Tag = $tag; $btn.Height=38
    $btn.Background = b "Transparent"; $btn.Foreground = b "#5a6d80"
    $btn.BorderThickness=[System.Windows.Thickness]::new(0);$btn.Padding=[System.Windows.Thickness]::new(14,0,14,0)
    $btn.HorizontalContentAlignment="Left";$btn.Cursor=[System.Windows.Input.Cursors]::Hand
    $btn.Margin=[System.Windows.Thickness]::new(6,1,6,1);$btn.FontSize=12.5
    $sp = New-Object Windows.Controls.StackPanel; $sp.Orientation="Horizontal"
    $sp.Children.Add((L "$icon  " 14))|Out-Null
    $sp.Children.Add((L $text 12.5))|Out-Null
    $btn.Content = $sp
    $btn.Add_Click({ NavTo $this.Tag })
    $nav.Children.Add($btn)|Out-Null
    return $btn
}

NavBtn "环境检测" "Check" "🔍"
NavBtn "安装预演" "Preview" "📋"
NavBtn "一键安装" "Install" "⚡"
NavBtn "更新下载" "Update" "🔄"
NavBtn "配置管理" "Config" "⚙️"

# Init
NavTo "Check"
$win.ShowDialog()|Out-Null
