# deploy_web.ps1
# Deploys the frontend (Firebase Hosting) and backend (Cloud Run) to production.
# Run this whenever you change receipt.html, Python routes, or any web-facing file.

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   Snap Khata - Web Deployment Script   " -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# ── 1. Deploy Backend to Cloud Run ─────────────────────────────────────────
Write-Host "[1/2] Deploying backend to Cloud Run..." -ForegroundColor Yellow
Set-Location -Path "c:\Users\MSi\Documents\SnapKhata\backend"
gcloud run deploy snap-khata-backend --source . --region asia-south1 --allow-unauthenticated --project snap-khata-prod-1152 --min-instances=0 --max-instances=3 --quiet
if ($LASTEXITCODE -ne 0) {
    Write-Error "Backend deployment failed."
    exit $LASTEXITCODE
}
Write-Host "Backend deployed successfully!" -ForegroundColor Green

# ── 2. Deploy Frontend to Firebase Hosting ─────────────────────────────────
Write-Host "`n[2/2] Deploying frontend to Firebase Hosting..." -ForegroundColor Yellow
Set-Location -Path "c:\Users\MSi\Documents\SnapKhata\frontend"
firebase deploy --only hosting
if ($LASTEXITCODE -ne 0) {
    Write-Error "Frontend deployment failed."
    exit $LASTEXITCODE
}
Write-Host "Frontend deployed successfully! (mydigientry.com updated)" -ForegroundColor Green
