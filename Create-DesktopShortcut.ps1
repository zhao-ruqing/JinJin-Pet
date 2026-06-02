$ErrorActionPreference = "Stop"
$AppDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$StartScript = Join-Path $AppDir "Start-JinjinPet.vbs"
$DesktopDir = [Environment]::GetFolderPath("Desktop")
$ShortcutPath = Join-Path $DesktopDir "Jinjin Pet.lnk"

$Shell = New-Object -ComObject WScript.Shell
$Shortcut = $Shell.CreateShortcut($ShortcutPath)
$Shortcut.TargetPath = "wscript.exe"
$Shortcut.Arguments = "`"$StartScript`""
$Shortcut.WorkingDirectory = $AppDir
$Shortcut.WindowStyle = 7
$Shortcut.Description = "Start Jinjin Pet"
$Shortcut.Save()

Write-Output "Created desktop shortcut: $ShortcutPath"
