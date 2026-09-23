# Backend operations

This document describes the production behavior of the current `main` branch.

## Production configuration

Required:

```text
ENVIRONMENT=production
JWT_SECRET=<at least 32 random characters>
ADMIN_TOKEN=<long random admin bearer token>
DATABASE_URL=<managed PostgreSQL connection string>
CORS_ALLOWED_ORIGINS=<comma-separated HTTPS origins>
```

The backend reads these values from Render environment variables in production.
Do not commit secrets, `.env` files, SMTP credentials, or generated signing
keys.

The backend requires PostgreSQL in production because the Render filesystem is
not durable. SQLite is for local development and tests only.

## Live routes

For the current Render service:

```text
https://usizoai.onrender.com/
https://usizoai.onrender.com/admin/
https://usizoai.onrender.com/health
https://usizoai.onrender.com/api/
https://usizoai.onrender.com/download
```

The admin dashboard uses the `ADMIN_TOKEN` value as a bearer token. It is not
the same as a customer password.

## Android APK downloads

`/download` returns a `302` redirect to the newest published GitHub release
asset:

```text
https://github.com/phallenges/usizo_ai_web/releases/latest/download/UsizoAI.apk
```

GitHub resolves `latest` to the most recent release that is neither a draft nor
a pre-release. Publishing a release therefore updates the public download with
no backend change. Two rules follow from this:

- Publish each new APK as a normal (non-pre-release) release whose asset is
  named `UsizoAI.apk`.
- Delete superseded releases. Re-publishing an older tag would make that tag
  `latest` again and silently regress the download.

Set `APK_DOWNLOAD_URL` in Render to override the default and pin an exact
release when a rollback is needed.

### Version checks

`GET /api/app/version` reports the published build so an installed app can
decide whether to update:

```text
GET /api/app/version?currentVersion=1.0.0
```

```json
{
  "ok": true,
  "latestVersion": "1.1.0",
  "latestTag": "v1.1.0",
  "downloadUrl": "https://github.com/phallenges/usizo_ai_web/releases/latest/download/UsizoAI.apk",
  "currentVersion": "1.0.0",
  "updateAvailable": true,
  "minimumVersion": null,
  "updateRequired": false
}
```

The endpoint reads the newest release from the GitHub API and caches it for
`APP_VERSION_CACHE_SECONDS` (default `600`) so repeated checks cannot exhaust
the unauthenticated rate limit. Optional Render variables:

```text
GITHUB_TOKEN=<token that raises the GitHub API rate limit>
APP_LATEST_VERSION=<version to report when GitHub is unreachable>
APP_MINIMUM_VERSION=<oldest supported version; older apps get updateRequired>
APP_VERSION_CACHE_SECONDS=600
```

The `+build` metadata in versions such as `1.1.0+2` is accepted encoded or
unencoded. Because the APK is self-distributed, installing an update still
requires the Android package installer, so the person must confirm the install;
fully silent background updates require Google Play distribution.

## Plus payment and token operations

The current flow is manual EcoCash verification:

1. The customer opens **Pay with EcoCash**.
2. The customer pays the displayed amount to the configured UsizoAI number.
3. EcoCash sends a confirmation message and transaction reference.
4. The customer submits the reference, confirmation message, and delivery email
   from the app.
5. The backend stores a pending payment submission.
6. The admin independently verifies the payment in EcoCash.
7. The admin opens **Plus Payments** and approves or rejects the submission.
8. On approval, the backend creates a random single-use token and emails it to
   the submitted email address.
9. The customer enters the token in **Activate Plus**.
10. The backend stores only a token digest and marks the token redeemed after
    successful activation.

A payment is not approved merely because a customer supplied a screenshot,
reference, or message. If SMTP delivery fails, approval fails and no token is
issued.

## SMTP token delivery

Configure these Render variables:

```text
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=<sending Gmail address>
SMTP_PASSWORD=<Gmail App Password, not the normal password>
SMTP_FROM=UsizoAI <sending Gmail address>
```

For Gmail, enable 2-Step Verification and create an App Password. Remove
spaces from the App Password before saving it in Render. Redeploy after
changing environment variables.

## Marketplace payment proof

Marketplace EcoCash payments are separate from Plus:

1. The customer creates an order.
2. The supplier confirms payment instructions.
3. The customer pays the supplier externally.
4. The customer uploads a payment confirmation image.
5. The supplier reviews the proof and confirms or rejects the order.

This flow does not process payments automatically.

## Database and backups

The schema is initialized on service startup. Back up PostgreSQL before
production migrations or operational changes. Test restoration, not only backup
creation. Payment confirmations and audit events should be retained according
to the business privacy and retention policy.

## Local operations

```powershell
cd backend
py run.py
backend\.venv\Scripts\python.exe -m pytest -q backend\tests
```

The production container uses `PORT` supplied by Render. Do not hard-code a
public host or expose database credentials to the Flutter app.
