# 用途：移除 Codex++ 工作日定时启动的计划任务
# 用法：powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Uninstall-CodexSchedule.ps1

$ErrorActionPreference = "Stop"
$TaskName = "Jinjin Pet - Codex++"

$Existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($Existing) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Output "已移除计划任务：$TaskName"
} else {
    Write-Output "未找到计划任务：$TaskName"
}