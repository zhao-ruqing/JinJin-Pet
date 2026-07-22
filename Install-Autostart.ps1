# 用途：注册 Windows 计划任务，用户登录时自动启动进进宠物
# 用法：powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install-Autostart.ps1
#
# 切换自启方式（改这一行即可）：
#   "codex"  = 与 Codex++ 相同：显式 Interactive 主体（推荐，更稳）
#   "legacy" = 原有方式：不指定 Principal，仅 AtLogOn 触发
$AutostartMode = "codex"

$ErrorActionPreference = "Stop"
$AppDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$StartScript = Join-Path $AppDir "Start-JinjinPet.vbs"
$TaskName = "Jinjin Pet"

if ($AutostartMode -notin @("codex", "legacy")) {
    Write-Error "无效的 AutostartMode：$AutostartMode（仅支持 codex / legacy）"
}

if (-not (Test-Path -LiteralPath $StartScript)) {
    Write-Error "找不到启动脚本：$StartScript"
}

$StartupDir = [Environment]::GetFolderPath("Startup")
$OldShortcutPath = Join-Path $StartupDir "Jinjin Pet.lnk"
if (Test-Path -LiteralPath $OldShortcutPath) {
    Remove-Item -LiteralPath $OldShortcutPath -Force
}

$Action = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "`"$StartScript`""
$Trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME

if ($AutostartMode -eq "codex") {
    $Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    $Principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive
    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -Principal $Principal -Description "Start Jinjin Pet at user logon (codex mode)" -Force | Out-Null
} else {
    $Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero)
    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -Description "Start Jinjin Pet at user logon (legacy mode)" -Force | Out-Null
}

Write-Output "Installed scheduled task: $TaskName (mode=$AutostartMode)"
