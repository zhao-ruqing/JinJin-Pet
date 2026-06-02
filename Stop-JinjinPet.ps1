Get-CimInstance Win32_Process |
    Where-Object { $_.CommandLine -like "*JinjinPet.ps1*" } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
