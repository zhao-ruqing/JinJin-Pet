$StartupDir = [Environment]::GetFolderPath("Startup")
$ShortcutPath = Join-Path $StartupDir "Jinjin Pet.lnk"
if (Test-Path -LiteralPath $ShortcutPath) {
    Remove-Item -LiteralPath $ShortcutPath
    Write-Output "Removed autostart shortcut: $ShortcutPath"
} else {
    Write-Output "Autostart shortcut not found: $ShortcutPath"
}
