# Production deployment

## Architecture

UsizoAI production consists of:

- Flutter Android client
- FastAPI web service
- Managed PostgreSQL database
- Render deployment
- SMTP provider for Plus activation emails
- GitHub Release asset for the Android APK

The Android app contains no backend secrets. It only receives the public API
base URL at build time.

## Render Blueprint

The repository includes `render.yaml` for:

- Web service: `usizoai-api`
- Docker build context: `backend/`
- Health check: `/health`
- PostgreSQL database: `usizoai-db`
- Automatic deploys from the configured branch

Create or update the Render Blueprint from the GitHub repository, then confirm
the generated public service domain in Render. The currently used service is:

```text
https://usizoai.onrender.com
```

Do not assume a service hostname if Render shows a different domain.

## Required Render variables

Set these in the web service environment:

```text
ENVIRONMENT=production
JWT_SECRET=<generated secret, at least 32 characters>
ADMIN_TOKEN=<generated admin token>
DATABASE_URL=<provided by the usizoai-db Render database>
CORS_ALLOWED_ORIGINS=https://usizoai.onrender.com
SEED_SUPPLIER_PIN=<supplier portal PIN, defaults to 1234>
```

For automatic Plus token email delivery, also set:

```text
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=motsutreasure@gmail.com
SMTP_PASSWORD=<Gmail App Password>
SMTP_FROM=UsizoAI <motsutreasure@gmail.com>
```

Never use the normal Gmail password. Enable 2-Step Verification and create a
Gmail App Password for SMTP.

## Deploy the backend

After pushing to the deployment branch:

1. Open the Render service.
2. Confirm the new commit appears under **Events**.
3. Wait for the deploy to become **Live**.
4. Check:

```text
https://usizoai.onrender.com/health
https://usizoai.onrender.com/
https://usizoai.onrender.com/admin/
```

The health endpoint must return HTTP 200 before releasing an APK that depends
on the backend.

## Build the Android app

For a public release using the default API origin:

```powershell
flutter pub get
flutter build apk --release
```

If the API has another public hostname:

```powershell
flutter build apk --release `
  --dart-define=USIZO_API_BASE_URL=https://your-api-host.example
```

The generated APK is normally:

```text
build\app\outputs\flutter-apk\app-release.apk
```

If Flutter reports an output-detection error after Gradle succeeds, check:

```text
android\app\build\outputs\flutter-apk\app-release.apk
```

Rename the release asset to `UsizoAI.apk` before uploading it to GitHub
Releases. Keep generated APKs out of Git history.

Publish the release as a normal release, not a pre-release, because `/download`
serves the newest non-draft, non-pre-release release. Delete the release it
replaces so an older tag cannot become `latest` again.

Increment the version in `pubspec.yaml` for every release, for example
`1.2.0+3`. The build number after `+` is the Android `versionCode`; Android
refuses to install an update whose `versionCode` is not higher than the
installed build. The `versionName` before `+` is what the app reports to
`/api/app/version`.

## In-app updates

The app checks `/api/app/version` after startup and, when a newer build is
published, offers a one-tap update: it downloads the APK in the background with
progress and then hands it to the Android package installer. The person still
confirms the install, because Android never installs a sideloaded APK silently.

What this requires:

- `REQUEST_INSTALL_PACKAGES` in `AndroidManifest.xml`, plus the
  `${applicationId}.updates` `FileProvider` declared for the updater.
- The downloads are staged in the app cache under `updates/`.
- The release keystore must be the same one used for the installed build,
  otherwise Android rejects the update. Back up `android/app/*.jks` and
  `android/key.properties`; they are intentionally not in Git.

If the person has not allowed installs from this app yet, the app opens the
"install unknown apps" screen and asks them to tap **Update now** again.

## Release checklist

- Backend tests pass.
- `flutter analyze` has no errors.
- `/health`, `/`, and `/admin/` return HTTP 200.
- PostgreSQL is connected and durable.
- SMTP sends a test message.
- Plus payment approval does not issue a token if SMTP fails.
- EcoCash payment verification remains manual.
- The APK points to the correct public API origin.
- The GitHub Release asset is named `UsizoAI.apk`.
- The new release is published as a normal release and the superseded one is deleted.
- `/download` returns HTTP 302 to the intended release.
- `/api/app/version` reports the new version, or the `atom`/`static` fallback.
- `APP_LATEST_VERSION` in `backend/app/main.py` matches the newest release.
- `pubspec.yaml` version and build number are higher than the previous release.
- The in-app update prompt downloads and installs the new build on a real device.
- The release keystore used for the build matches the installed build's key.
- Privacy, health-safety, retention, and support procedures are reviewed.
