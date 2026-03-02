# deploy_and_test_mobile.ps1

$ErrorActionPreference = "Stop"

Write-Host "Starting deployment process..." -ForegroundColor Cyan

# 1. Deploy backend
Write-Host "`n[1/3] Deploying backend to Cloud Run..." -ForegroundColor Yellow
Set-Location -Path "c:\Users\MSi\Documents\Superbase\backend"
gcloud run deploy snap-khata-backend --source . --region asia-south1 --allow-unauthenticated --quiet
if ($LASTEXITCODE -ne 0) {
    Write-Error "Backend deployment failed."
    exit $LASTEXITCODE
}
Write-Host "Backend deployment successful!" -ForegroundColor Green

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
