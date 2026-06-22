# Otter — Windows release bundle (run on Windows with Flutter desktop enabled).
# Usage: powershell -ExecutionPolicy Bypass -File scripts/build_windows.ps1

$ErrorActionPreference = "Stop"
Set-Location (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))

Write-Host "==> Otter Windows release build" -ForegroundColor Cyan

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw "Flutter not found in PATH. Install: https://docs.flutter.dev/get-started/install/windows"
}

if (-not (Test-Path ".env")) {
    Write-Host "==> Creating .env from .env.example" -ForegroundColor Yellow
    Copy-Item ".env.example" ".env"
}

Write-Host "==> flutter pub get"
flutter pub get

Write-Host "==> flutter analyze lib"
flutter analyze lib
if ($LASTEXITCODE -ne 0) { throw "Analyzer failed" }

Write-Host "==> flutter test"
flutter test
if ($LASTEXITCODE -ne 0) { throw "Tests failed" }

Write-Host "==> flutter build windows --release"
flutter build windows --release
if ($LASTEXITCODE -ne 0) { throw "Windows build failed" }

$releaseDir = Join-Path "build" "windows\x64\runner\Release"
if (-not (Test-Path $releaseDir)) {
    throw "Release folder not found: $releaseDir"
}

$version = (Select-String -Path "pubspec.yaml" -Pattern "^version:\s*(.+)$").Matches[0].Groups[1].Value.Trim()
$versionSafe = $version -replace "[^0-9A-Za-z.+_-]", "_"
$distDir = "dist"
$zipName = "otter-windows-x64-$versionSafe.zip"
$zipPath = Join-Path $distDir $zipName

New-Item -ItemType Directory -Force -Path $distDir | Out-Null
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

Write-Host "==> Packaging $zipPath"
Compress-Archive -Path (Join-Path $releaseDir "*") -DestinationPath $zipPath -Force

Write-Host ""
Write-Host "Done." -ForegroundColor Green
Write-Host "  Executable: $releaseDir\otter_mobile.exe"
Write-Host "  Archive:    $zipPath"
Write-Host ""
Write-Host "Copy the whole Release folder (or the zip) to distribute the app."
