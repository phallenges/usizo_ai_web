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
- Privacy, health-safety, retention, and support procedures are reviewed.
