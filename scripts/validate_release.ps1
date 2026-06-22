# Pre-release checks (Windows or macOS with Flutter installed).
$ErrorActionPreference = "Stop"
Set-Location (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))

if (-not (Test-Path ".env")) {
    Copy-Item ".env.example" ".env"
}

flutter pub get
flutter analyze lib
if ($LASTEXITCODE -ne 0) { exit 1 }

flutter test
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host "Validation passed." -ForegroundColor Green
