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
SEED_SUPPLIER_PIN=<4-64 digit supplier portal PIN; required, no default>
```

The service refuses to start in production until `SEED_SUPPLIER_PIN` is set
to a 4–64 digit value. Set it in the Render dashboard (it is declared with
`sync: false` in `render.yaml` so the value never lives in the repository).

### Plus activation token email

Approved Plus payments email a single-use activation token. Render's free
instance type blocks outbound traffic to SMTP ports 25, 465, and 587, so the
SMTP settings below only work on a paid instance type. Set an HTTPS provider
instead:

```text
EMAIL_FROM=UsizoAI <verified-sender@example.com>
MAILJET_API_KEY=<Mailjet API key>
MAILJET_SECRET_KEY=<Mailjet secret key>
```

Transports are auto-selected in this order, and the first one that is fully
configured is used:

1. `mailjet` — `MAILJET_API_KEY` and `MAILJET_SECRET_KEY`. The free plan
   includes 6,000 emails a month with a 200/day cap and needs no card. Add the
   sender under **Account → Add a Sender Address**, then click the confirmation
   link in that mailbox. Mailjet accepts a Gmail sender but warns that freemail
   senders are filtered more often, so expect some mail in spam.
2. `brevo` — `BREVO_API_KEY`. 300 emails/day free, and the account must be
   approved for sending before the API will deliver anything.
3. `sendgrid` — `SENDGRID_API_KEY`. **There is no permanent free plan:** Twilio
   retired it on 27 May 2025, and new accounts get a 60-day trial of 100
   emails/day after which sending stops until a paid plan is selected.
4. `smtp` — the `SMTP_*` variables, which need a paid instance type.

Set `EMAIL_TRANSPORT` to pin one of `mailjet`, `brevo`, `sendgrid` or `smtp`.
A pin that is unknown or incompletely configured reports
`Email delivery is not configured.` instead of quietly falling back, and an
unknown name is ignored with a warning in the logs. This matters when a key for
a provider whose account cannot send is still present: pin the working provider
so it cannot shadow it.

`EMAIL_FROM` falls back to `SMTP_FROM` and must be the sender address verified
at the provider. Verify delivery from the operations dashboard with
**Plus Tokens → Send test email**, which reports the transport in use and the
provider's own error message.

Sending as `@gmail.com` from a third party is the root cause of most provider
rejections and filtering: Postmark, SMTP2GO and Resend refuse free domains
outright, while Brevo, Mailjet and SendGrid all warn about it. Owning a domain
(about $10/year) and authenticating it removes the problem permanently and
opens every provider.

On a paid instance type, or when self-hosting, Gmail SMTP still works:

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
- Email delivery is configured (`BREVO_API_KEY` or `SENDGRID_API_KEY` plus
  `EMAIL_FROM`; raw SMTP requires a paid instance type) and the dashboard's
  **Plus Tokens → Send test email** reports success.
- Plus payment approval emails the token, or is approved without email and the
  token is handed to the customer manually.
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
