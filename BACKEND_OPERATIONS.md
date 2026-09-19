# Backend operations and launch controls

The current payment model remains manual EcoCash payment followed by a Plus
activation token. It does not process or store card/payment credentials.

## Production configuration

Copy `backend/.env.example` to `backend/.env`, set a unique `JWT_SECRET` of at
least 32 characters, and set the exact `CORS_ALLOWED_ORIGINS` for the deployed web/admin clients. Set
`ENVIRONMENT=production`; this disables API docs and auto-reload.

The health chat requires the server-only `LLM_BASE_URL`, `LLM_API_KEY`, and
`LLM_MODEL` variables from `backend/.env.example`. The endpoint uses the
standard OpenAI-compatible `/v1/chat/completions` contract and keeps the API
key off-device. Non-Plus devices are limited to three chat requests per UTC
calendar month; usage is stored in PostgreSQL in `llm_usage_monthly`.

Run the API from `backend/` with `py -m uvicorn app.main:app --host 0.0.0.0 --port 3000` behind HTTPS at a reverse proxy. Production requires a managed PostgreSQL database configured through `DATABASE_URL`; SQLite is local-development/test only. Use a TLS-enabled connection string from the provider (for example, one containing `sslmode=require`) and keep the pool within the provider's connection limit with `DATABASE_POOL_MIN` and `DATABASE_POOL_MAX`.

The public landing page is served at `/` (with `/index.html` as an alias), the
operations dashboard at `/admin/`, the API status at `/api/`, and the favicon
at `/favicon.ico` or `/favicon.png`. The `/download` endpoint redirects to
the current Android APK release. Set `APK_DOWNLOAD_URL` to the exact HTTPS
download URL for the published APK (the default points to the `v1.0.0`
`UsizoAI.apk` asset in this repository's GitHub Releases). Update this
value when publishing a new release. Keep the APK in a
release or object store rather than committing the generated binary to the
repository or bundling it into the API image.

## Free preview deployment

The repository includes `render.yaml` and `backend/Dockerfile` for a no-cost
Render preview service and PostgreSQL database. Create a Render Blueprint from
the repository, set `CORS_ALLOWED_ORIGINS` to the app origin (add additional
comma-separated origins if needed), and use the generated service URL as
`USIZO_API_BASE_URL` when building Flutter:

```powershell
flutter build appbundle --dart-define=USIZO_API_BASE_URL=https://usizoai-api.onrender.com
```

The free service may sleep when idle. The Blueprint provisions the named
managed PostgreSQL instance and wires its connection string into
`DATABASE_URL`. Do not point production at
`DATABASE_PATH` or `/tmp`; those files are not durable.

Build the customer app with the public API origin (never a secret) so Plus
tokens are redeemed by the server rather than validated on-device:

```powershell
flutter build appbundle --dart-define=USIZO_API_BASE_URL=https://api.example.com
```

## Manual Plus activation

After an operator verifies an EcoCash payment, issue a token once:

```powershell
cd backend
py -m app.create_activation_token --reference ECOCASH-TRANSACTION-REFERENCE
```

Send the printed token privately to that customer. The database retains only a
SHA-256 digest. A token can be redeemed by one device once; it cannot be
reused or guessed from the old checksum format.

## Release gates still owned by the business

- Add vetted products for Treasure Motsu and verify supplier, product-safety,
  fulfilment, refund, and support processes before publishing them.
- Serve the API and any web/admin client over HTTPS; take encrypted database
  backups and test restoration.
- Review the existing authenticated customer account and medical-profile flows
  before storing additional sensitive health information.
- Complete the medical/legal review of remedy content, emergency copy, privacy
  notice, consent, retention policy, and applicable health/product rules in
  every launch market.
- Configure monitoring, error alerting, distributed rate limiting if the
  service scales beyond one process, and an incident-response contact before
  public release. The API currently applies per-process, per-IP limits.
