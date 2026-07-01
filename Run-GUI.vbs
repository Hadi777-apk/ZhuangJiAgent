' AI 开发环境初始化工具 GUI v2.5.3
' 双击此文件启动 GUI，后台无终端窗口，自动请求管理员权限

Dim scriptDir, psScript
scriptDir = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)
psScript = scriptDir & "\gui.ps1"

Dim objShell
Set objShell = CreateObject("Shell.Application")
' ShellExecute(操作, 参数, 目录, 动词, 窗口状态)
' runas = 管理员权限, 0 = 隐藏窗口
objShell.ShellExecute "powershell.exe", _
    "-NoProfile -ExecutionPolicy Bypass -File """ & psScript & """", _
    scriptDir, "runas", 0

Set objShell = Nothing
