#!/usr/bin/env bash
# Builds FaceBaby Admin (lib/main_admin.dart) into build/admin_web and deploys hosting:admin.
# Usage (from repo root): ./scripts/deploy_admin_web.sh

set -euo pipefail
cd "$(dirname "$0")/.."

BUILD_LABEL="Admin build v4"
PROJECT="facebaby-afc41"

echo "==> Cleaning stale admin web build..."
rm -rf build/admin_web

echo "==> flutter build web (main_admin.dart -> build/admin_web)..."
flutter build web --release \
  -t lib/main_admin.dart \
  --base-href / \
  --output build/admin_web \
  --dart-define="ADMIN_BUILD_LABEL=${BUILD_LABEL}"

test -f build/admin_web/index.html || { echo "build/admin_web/index.html missing"; exit 1; }

cp -f admin_panel/web/index.html build/admin_web/index.html
cp -f admin_panel/web/manifest.json build/admin_web/manifest.json 2>/dev/null || true

if ! grep -q "FaceBaby Admin" build/admin_web/index.html; then
  echo "ERROR: build is not the admin panel. Use -t lib/main_admin.dart"
  exit 1
fi

echo "==> Deploying Cloud Functions + hosting:admin..."
firebase deploy --only \
  "functions:ensureAdminPanelAccess,functions:adminGetPhotoBytes,functions:previewAdminBroadcastAudience,functions:publishAdminBroadcast,hosting:admin" \
  --project "$PROJECT"

echo ""
echo "Done. Open: https://facebaby-admin.web.app/#/login"
echo "Footer must show: ${BUILD_LABEL}"
echo "Hard-refresh (Ctrl+Shift+R) if the browser cached the main app bundle."
