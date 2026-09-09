# Build Flutter Windows release + OpenFliqlo.scr
$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$App = Join-Path $Root "apps\open_fliqlo"
$Scr = Join-Path $Root "platforms\windows_scr"
$Out = Join-Path $Root "dist\windows-screensaver"

Write-Host "Building Flutter Windows release..."
Push-Location $App
flutter build windows --release
Pop-Location

$FlutterOut = Join-Path $App "build\windows\x64\runner\Release"
New-Item -ItemType Directory -Force -Path $Out | Out-Null
Copy-Item -Recurse -Force "$FlutterOut\*" $Out

Write-Host "Building SCR host..."
Push-Location $Scr
dotnet publish -c Release -r win-x64 --self-contained false -o (Join-Path $Scr "bin")
Pop-Location

Copy-Item (Join-Path $Scr "bin\OpenFliqlo.exe") (Join-Path $Out "OpenFliqlo.scr") -Force
Write-Host "Wrote $Out\OpenFliqlo.scr"
Write-Host "Copy the folder to a Windows PC and pick OpenFliqlo.scr in Screen Saver settings."
