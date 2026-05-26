# FaceBaby Admin Web Panel

Separate Flutter **web** app using the same Firebase project as the mobile app (`facebaby-afc41`). Not included in mobile navigation.

## First-time setup

1. In Firebase Console → Firestore, create your **email allowlist** (stable; survives deleting the mobile app account):

   **Collection:** `admins_by_email`  
   **Document ID:** your email in **lowercase** (e.g. `tamorim9000@gmail.com`)  
   **Fields:**

   ```json
   {
     "email": "tamorim9000@gmail.com",
     "role": "owner",
     "active": true
   }
   ```

   On first login, the callable **`ensureAdminPanelAccess`** creates **`admins/{currentAuthUid}`** and can migrate from a legacy **`admins`** doc with the same email.

   Alternatively set `ADMIN_BOOTSTRAP_EMAILS` in `functions/.env.facebaby-afc41` (comma-separated) and redeploy that function.

   Allowed roles: **`owner`** or **`admin`**. Set **`active: false`** to revoke access.

2. In **Firebase Console → Authentication → Sign-in method**, enable **Google** (required for “Entrar com Google” on web).

3. Deploy Firestore + Storage rules from repo root:

   ```bash
   firebase deploy --only firestore:rules,storage
   ```

   Storage rules allow **owner/admin** (`admins/{uid}`) to read user photos for the panel.

4. **Web images (CORS):** if photos still fail with network widgets, apply bucket CORS once (Google Cloud SDK):

   ```bash
   gsutil cors set storage/cors.json gs://facebaby-afc41.firebasestorage.app
   ```

   The admin panel loads photos via **Firebase Storage `getData()`** (no browser CORS); deploy storage rules above so admins can read `users/{uid}/...` paths.

5. Run the panel from the **repo root** (recommended):

   ```bash
   flutter pub get
   flutter run -d chrome -t lib/main_admin.dart
   ```

   Legacy (standalone `admin_panel/` package):

   ```bash
   cd admin_panel
   flutter pub get
   flutter run -d chrome
   ```

## Features

- Firebase Auth login (email/password + Google)
- Access check: `admins_by_email/{email}` allowlist, then `admins/{currentAuthUid}` session doc (`active == true`, role `owner` | `admin`)
- Access Denied page otherwise
- Dashboard, Users, Family details, Weekly Photo, Public Memories
- Suspend / reactivate user, manual plan change, logout
- Audit logs (`admin_logs`) with filters (admin, action, user, date)

## Audit log actions

Written to Firestore `admin_logs` on: admin login, suspend/reactivate, plan change, hide public memory, weekly winner, inappropriate content.

## Build & deploy (Firebase Hosting `admin` → site `facebaby-admin`)

Hosting serves **`build/admin_web`** only (`firebase.json` → `"public": "build/admin_web"`).  
**Never** deploy `hosting:admin` after `flutter build web` without `-t lib/main_admin.dart` — that would publish the mobile app on the admin URL.

From repo root:

```bash
# Windows
.\scripts\deploy_admin_web.ps1

# macOS / Linux
chmod +x scripts/deploy_admin_web.sh
./scripts/deploy_admin_web.sh
```

Manual steps:

```bash
rm -rf build/admin_web
flutter build web --release -t lib/main_admin.dart --base-href / \
  --output build/admin_web \
  --dart-define=ADMIN_BUILD_LABEL="Admin build v2"
firebase deploy --only hosting:admin --project facebaby-afc41
```

Photos in Weekly Photo / Public Memories use the callable **`adminGetPhotoBytes`** (server-side download). Deploy that function together with hosting.

After deploy, the login page footer must show **`Admin build v3`**.  
If you still see an old error, hard-refresh (Ctrl+Shift+R) or clear site data for the admin URL.
