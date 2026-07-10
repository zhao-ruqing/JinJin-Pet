# 用途：注册 Windows 计划任务，工作日定时通过 VBS 启动 Codex++
# 用法：powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install-CodexSchedule.ps1

$ErrorActionPreference = "Stop"
$AppDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$StartScript = Join-Path $AppDir "Start-CodexPlusPlus.vbs"
$CodexExe = "D:\ALL-APP\codex++\codex-plus-plus.exe"
$TaskName = "Jinjin Pet - Codex++"
$LaunchTime = "17:58"

# 启动前检查 Codex++ 与 VBS 启动脚本是否存在
if (-not (Test-Path -LiteralPath $CodexExe)) {
    Write-Error "找不到 Codex++：$CodexExe"
}
if (-not (Test-Path -LiteralPath $StartScript)) {
    Write-Error "找不到启动脚本：$StartScript"
}

$Action = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "`"$StartScript`""
$Trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday, Tuesday, Wednesday, Thursday, Friday -At $LaunchTime
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
$Principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive
Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -Principal $Principal -Description "工作日 $LaunchTime 自动启动 Codex++" -Force | Out-Null

Write-Output "已安装计划任务：$TaskName（周一至周五 $LaunchTime）"
