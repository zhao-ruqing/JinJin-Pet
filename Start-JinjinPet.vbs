Set shell = CreateObject("WScript.Shell")
appDir = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)
script = appDir & "\Start-JinjinPet.ps1"
shell.Run "powershell.exe -NoProfile -File """ & script & """", 0, False
