# Sync legal text assets into Firebase Hosting public folder.
$Root = Split-Path -Parent $PSScriptRoot
$LegalDir = Join-Path $Root "public\legal"
New-Item -ItemType Directory -Force -Path $LegalDir | Out-Null
Copy-Item (Join-Path $Root "assets\terms\terms_en_US.txt") (Join-Path $LegalDir "terms_en_US.txt") -Force
Copy-Item (Join-Path $Root "assets\privacy\privacy_en_US.txt") (Join-Path $LegalDir "privacy_en_US.txt") -Force
Write-Host "Synced legal files to public/legal/"
