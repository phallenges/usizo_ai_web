# Backend operations and launch controls

The current payment model remains manual EcoCash payment followed by a Plus
activation token. It does not process or store card/payment credentials.

## Production configuration

Copy `backend/.env.example` to `backend/.env`, set a unique `JWT_SECRET` of at
least 32 characters, and set the exact `CORS_ALLOWED_ORIGINS` for the deployed
web/admin clients. Set `ENVIRONMENT=production`; this disables API docs,
auto-reload, and demo seeding by default.

Run the API from `backend/` with `py -m uvicorn app.main:app --host 0.0.0.0 --port 3000` behind HTTPS at a reverse proxy. Production requires a managed PostgreSQL database configured through `DATABASE_URL`; SQLite is local-development/test only. Use a TLS-enabled connection string from the provider (for example, one containing `sslmode=require`) and keep the pool within the provider's connection limit with `DATABASE_POOL_MIN` and `DATABASE_POOL_MAX`.

## Free preview deployment

The repository includes `render.yaml` and `backend/Dockerfile` for a no-cost
Render preview service. Create a Render Blueprint from the repository, set
`CORS_ALLOWED_ORIGINS` to the app origin, and use the generated service URL as
`USIZO_API_BASE_URL` when building Flutter:

```powershell
flutter build appbundle --dart-define=USIZO_API_BASE_URL=https://usizoai-api.onrender.com
```

The free service may sleep when idle. Attach a managed PostgreSQL instance
(such as a provider offering a free development tier) and set its connection
string as the Render `DATABASE_URL` secret. Do not point production at
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

- Replace the seeded catalog with vetted vendors/products and verify supplier,
  product-safety, fulfilment, refund, and support processes.
- Serve the API and any web/admin client over HTTPS; take encrypted database
  backups and test restoration.
- Add authenticated customer accounts before storing sensitive health/profile
  information in the hosted backend. A device ID alone is not an identity.
- Complete the medical/legal review of remedy content, emergency copy, privacy
  notice, consent, retention policy, and applicable health/product rules in
  every launch market.
- Configure monitoring, error alerting, rate limiting at the reverse proxy,
  and an incident-response contact before public release.
