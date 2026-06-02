$ErrorActionPreference = "Stop"
$AppDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Incoming = Join-Path $AppDir "incoming"

if (-not (Test-Path -LiteralPath $Incoming)) {
    New-Item -ItemType Directory -Path $Incoming | Out-Null
    Write-Output "Created $Incoming. Put the six new images there, then run this script again."
    exit 1
}

$Mapping = [ordered]@{
    "1" = "avatar.png"
    "2" = "coding.png"
    "3" = "happy-wave.png"
    "4" = "sleepy.png"
    "5" = "surprised.png"
    "6" = "thinking.png"
}

$ImageExtensions = @(".png", ".webp", ".jpg", ".jpeg")
foreach ($Pair in $Mapping.GetEnumerator()) {
    $Index = $Pair.Key
    $Name = $Pair.Value
    $Candidates = @()
    foreach ($Ext in $ImageExtensions) {
        $Candidates += Get-ChildItem -LiteralPath $Incoming -File -ErrorAction SilentlyContinue |
            Where-Object {
                $_.Name -eq $Name -or
                $_.BaseName -eq $Index -or
                $_.BaseName -eq $Index.PadLeft(2, "0") -or
                $_.BaseName -eq "图$Index" -or
                $_.BaseName -eq "image$Index"
            }
    }
    $Source = $Candidates | Select-Object -First 1
    if (-not $Source) {
        throw "Missing image $Index for $Name under $Incoming"
    }
    Copy-Item -LiteralPath $Source.FullName -Destination (Join-Path $AppDir $Name) -Force
    Write-Output "Imported $($Source.Name) -> $Name"
}

Copy-Item -LiteralPath (Join-Path $AppDir "avatar.png") -Destination (Join-Path $AppDir "idle.png") -Force

$Python = "python"

& $Python (Join-Path $AppDir "build_pet_from_sources.py")
& (Join-Path $AppDir "Start-JinjinPet.ps1")
