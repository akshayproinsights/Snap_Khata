# deploy_and_test_mobile.ps1

$ErrorActionPreference = "Stop"


# 2. Build Flutter APK
Write-Host "`n[2/3] Building Flutter APK..." -ForegroundColor Yellow
Set-Location -Path "c:\Users\MSi\Documents\Superbase\mobile"
flutter build apk
if ($LASTEXITCODE -ne 0) {
    Write-Error "Flutter APK build failed."
    exit $LASTEXITCODE
}
Write-Host "Flutter APK build successful!" -ForegroundColor Green

# 3. Install APK to connected device
Write-Host "`n[3/3] Installing APK to connected device..." -ForegroundColor Yellow
flutter install
if ($LASTEXITCODE -ne 0) {
    Write-Error "Flutter APK installation failed."
    exit $LASTEXITCODE
}
Write-Host "APK installation successful!" -ForegroundColor Green

Write-Host "`nDeployment process completed successfully!" -ForegroundColor Cyan
