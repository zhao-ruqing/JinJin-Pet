$ErrorActionPreference = "Stop"
$AppDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$StartScript = Join-Path $AppDir "Start-JinjinPet.vbs"
$TaskName = "Jinjin Pet"

$StartupDir = [Environment]::GetFolderPath("Startup")
$OldShortcutPath = Join-Path $StartupDir "Jinjin Pet.lnk"
if (Test-Path -LiteralPath $OldShortcutPath) {
    Remove-Item -LiteralPath $OldShortcutPath -Force
}

$Action = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "`"$StartScript`""
$Trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero)
Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -Description "Start Jinjin Pet at user logon" -Force | Out-Null

Write-Output "Installed scheduled task: $TaskName"
