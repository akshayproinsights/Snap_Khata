# deploy_and_test_mobile.ps1
# Builds the Flutter APK and installs it on a connected Android device for testing.
# Run this whenever you change mobile app code and want to test on a device.

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Snap Khata - Mobile Build & Install   " -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# 1. Build Flutter APK
Write-Host "[1/2] Building Flutter APK..." -ForegroundColor Yellow
Set-Location -Path "c:\Users\MSi\Documents\SnapKhata\mobile"
flutter build apk --release
if ($LASTEXITCODE -ne 0) {
    Write-Error "Flutter APK build failed."
    exit $LASTEXITCODE
}
Write-Host "Flutter APK build successful!" -ForegroundColor Green

# 2. Install APK to connected device
Write-Host "`n[2/2] Installing APK to connected Android device..." -ForegroundColor Yellow
flutter install
if ($LASTEXITCODE -ne 0) {
    Write-Error "Flutter APK installation failed."
    exit $LASTEXITCODE
}
Write-Host "APK installation successful!" -ForegroundColor Green

Write-Host "`nMobile build & install completed successfully!" -ForegroundColor Cyan
