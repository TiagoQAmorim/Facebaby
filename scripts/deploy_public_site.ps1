# Deploy FaceBaby public website (Firebase Hosting target: app)
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

& "$Root\scripts\sync_public_legal.ps1"

Write-Host "Deploying hosting (app target)..."
firebase deploy --only hosting:app

Write-Host ""
Write-Host "Public URLs (after DNS/custom domain):"
Write-Host "  https://www.thefacebaby.com/"
Write-Host "  https://www.thefacebaby.com/support/"
Write-Host "  https://www.thefacebaby.com/privacy/"
Write-Host "  https://www.thefacebaby.com/terms/"
