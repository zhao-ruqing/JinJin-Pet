$ErrorActionPreference = "Stop"
$TaskName = "Jinjin Pet"

$Existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($Existing) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Output "Removed scheduled task: $TaskName"
} else {
    Write-Output "Scheduled task not found: $TaskName"
}

$StartupDir = [Environment]::GetFolderPath("Startup")
$OldShortcutPath = Join-Path $StartupDir "Jinjin Pet.lnk"
if (Test-Path -LiteralPath $OldShortcutPath) {
    Remove-Item -LiteralPath $OldShortcutPath -Force
    Write-Output "Removed old startup shortcut: $OldShortcutPath"
}
