# Backend operations and launch controls

The current payment model remains manual EcoCash payment followed by a Plus
activation token. It does not process or store card/payment credentials.

## Production configuration

Copy `backend/.env.example` to `backend/.env`, set a unique `JWT_SECRET` of at
least 32 characters, and set the exact `CORS_ALLOWED_ORIGINS` for the deployed
web/admin clients. Set `ENVIRONMENT=production`; this disables API docs,
auto-reload, and demo seeding by default.

Run the API from `backend/` with `py -m uvicorn app.main:app --host 0.0.0.0 --port 3000` behind HTTPS at a reverse proxy. SQLite is suitable for a small,
single-instance launch only. Move to managed PostgreSQL before using multiple
API instances or expecting sustained concurrent writes.

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
