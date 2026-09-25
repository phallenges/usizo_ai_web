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

## Request security

- Device-scoped endpoints (`/api/devices/...`) require the `X-Device-Token`
  issued by `POST /api/devices/register`. The device id in the URL is not a
  credential: ids may leak through order payloads, so only the token grants
  access. Server-side only the token's SHA-256 hash is stored; devices that
  predate token issuance must re-register for a new identity.
- Rate limiting keys on the LAST entry of `X-Forwarded-For`, the entry the
  trusted reverse proxy (Render's router) appends. Deployments must run
  behind a proxy that appends this header — a direct public exposure would
  let clients spoof their rate-limit identity.
- Credential endpoints (`/api/auth/register`, `/api/auth/login`,
  `/api/vendors/login`, `/api/admin/login`) share the stricter per-IP bucket
  (`RATE_LIMIT_AUTH_PER_MINUTE`, default 10 per minute).

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
  "latestVersion": "1.2.0",
  "latestTag": "v1.2.0",
  "source": "github",
  "downloadUrl": "https://github.com/phallenges/usizo_ai_web/releases/latest/download/UsizoAI.apk",
  "currentVersion": "1.0.0",
  "updateAvailable": true,
  "minimumVersion": null,
  "updateRequired": false
}
```

The endpoint resolves the newest release in three tiers and reports which one
answered in `source`:

1. `github` - the GitHub API, which excludes drafts and pre-releases.
2. `atom` - the public release feed, used when the API rate limit is exhausted.
   The unauthenticated GitHub limit is 60 requests per hour per IP and Render
   shares its egress IP, so this fallback is expected in production.
3. `static` - `APP_LATEST_VERSION` plus the `/download` URL, used only when both
   GitHub endpoints are unreachable.

Successful lookups are cached for `APP_VERSION_CACHE_SECONDS` (default `600`),
and failures for 60 seconds, so repeated checks stay cheap. When the API is
rate-limited, setting `GITHUB_TOKEN` on Render restores the richest response
(notes and APK size). Optional Render variables:

```text
GITHUB_TOKEN=<token that raises the GitHub API rate limit>
APP_LATEST_VERSION=<static fallback; keep level with the newest release>
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
   **Approve & email token** emails the token to the address shown in the row;
   **Approve without email** issues the token and displays it once so it can be
   sent by hand.
8. On email approval, the backend creates a random single-use token and emails
   it to the submitted address, falling back to the linked account's email when
   the submission has none.
9. The customer enters the token in **Activate Plus**.
10. The backend stores only a token digest and marks the token redeemed after
    successful activation.

A payment is not approved merely because a customer supplied a screenshot,
reference, or message. If email delivery fails, approval fails and no token is
issued, so choose the manual path deliberately instead of losing the token. A
reference can only ever carry one token: approving a submission whose reference
already has a token returns HTTP 409.

## Activation token email delivery

Set an HTTPS provider on Render:

```text
EMAIL_FROM=UsizoAI <verified sender address>
MAILJET_API_KEY=<Mailjet API key>
MAILJET_SECRET_KEY=<Mailjet secret key>
```

The first transport that is fully configured is used, in this order:

| Transport | Variables | Notes |
| --- | --- | --- |
| `mailjet` | `MAILJET_API_KEY`, `MAILJET_SECRET_KEY`, `EMAIL_FROM` | HTTPS, works on free instances, 6,000/month with a 200/day cap |
| `brevo` | `BREVO_API_KEY`, `EMAIL_FROM` | HTTPS, works on free instances, 300/day, account approval required first |
| `sendgrid` | `SENDGRID_API_KEY`, `EMAIL_FROM` | HTTPS, but the free plan was retired in May 2025; new accounts get 60 days of 100/day |
| `smtp` | `SMTP_HOST`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `SMTP_FROM` | Blocked on Render's free instance type (ports 25, 465, and 587) |

Set `EMAIL_TRANSPORT` to pin one of them. An unknown or incompletely configured
pin reports `Email delivery is not configured.` rather than falling back, so a
stale key for a provider whose account cannot send cannot shadow the working
one. An unknown name is ignored, with a warning in the logs.

Mailjet can answer HTTP 200 while the individual message failed, so a
per-message `Status: error` in the response counts as a failure too. That is why
the dashboard never reports a token as emailed when it was not.

Verify from **Plus Tokens → Send test email** in the dashboard, or
`POST /api/admin/email-test` with `{"to": "you@example.com"}`. The response
reports the transport and the provider's own failure message, and is HTTP 200
with `"ok": false` when delivery failed.

Common failures:

| Message | Meaning |
| --- | --- |
| `Email delivery is not configured.` | No provider key and no complete SMTP block is set |
| `... brevo rejected the message (HTTP 401: Key not found).` | The API key is wrong or revoked |
| `... mailjet rejected the message (HTTP 401: API key authentication failure).` | The API key and secret key do not match |
| `... mailjet reported a send failure (Sender is not validated).` | The sender address was never confirmed in Mailjet |
| `... rejected the message (HTTP 400: ...)` | The sender address is not verified at the provider |
| `... could not be reached (ConnectError).` | Outbound HTTPS or SMTP is blocked, or the host is wrong |

For Gmail, enable 2-Step Verification and create an App Password. Remove spaces
from the App Password before saving it in Render. Redeploy after changing
environment variables.

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
