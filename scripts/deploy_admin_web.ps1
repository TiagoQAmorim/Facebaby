$ErrorActionPreference = "Stop"
$Project = "facebaby-afc41"
$BuildLabel = "Admin build v5"

Write-Host "Cleaning old admin web build..."
Remove-Item -Recurse -Force "build\admin_web" -ErrorAction SilentlyContinue

Write-Host "Building FaceBaby Admin Web (main_admin.dart -> build/admin_web)..."
flutter build web --release -t lib/main_admin.dart --base-href / `
  --output build/admin_web `
  --dart-define="ADMIN_BUILD_LABEL=$BuildLabel"

if (-not (Test-Path "build\admin_web\index.html")) {
    throw "build/admin_web/index.html missing - build failed."
}

Copy-Item -Force "admin_panel\web\index.html" "build\admin_web\index.html"
Copy-Item -Force "admin_panel\web\manifest.json" "build\admin_web\manifest.json" -ErrorAction SilentlyContinue

$html = Get-Content "build\admin_web\index.html" -Raw
if ($html -notmatch "FaceBaby Admin") {
    throw "Build is NOT the admin panel. Use: flutter build web -t lib/main_admin.dart --output build/admin_web"
}

Write-Host "Deploying admin functions + hosting:admin..."
firebase deploy --only "functions:ensureAdminPanelAccess,functions:adminGetPhotoBytes,functions:previewAdminBroadcastAudience,functions:publishAdminBroadcast,hosting:admin" --project $Project

Write-Host "Done."
Write-Host "Open: https://facebaby-admin.web.app/#/login"
Write-Host "Footer must show: $BuildLabel"
Write-Host "If photos still fail, confirm function deployed. Hard-refresh: Ctrl+Shift+R"
