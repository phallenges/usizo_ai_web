# UsizoAI

UsizoAI is a Flutter health-guidance app backed by FastAPI and PostgreSQL. It
provides educational symptom guidance, emergency-care prompts, a medical
profile, community remedy submissions, Plus activation, and a supplier
marketplace.

## Run the Flutter app

```bash
flutter pub get
flutter analyze
flutter run
```

The first launch shows the app tour and then requires a customer account.
Account data and medical profile updates are synchronized with the API when it
is available. The home checker provides a server-backed UsizoAI chat for health guidance and
app help. The server grounds responses in the remedy catalog's preparation,
warning, and research fields. The app still keeps the bundled catalog for
offline browsing, but chat requests require the configured API.

## Marketplace

The marketplace currently has one supplier: **Treasure Motsu** in Bulawayo,
phone/WhatsApp/EcoCash `+263 780747989`. The product catalog is intentionally
empty until products are added through the backend supplier workflow. Customers
select the supplier profile before viewing products; prices are not shown in
the customer interface.

Marketplace orders use manual EcoCash. The customer places a pending order,
contacts the supplier, pays externally, and submits payment confirmation for
supplier verification.

## Backend

The FastAPI service lives in `backend/app` and runs with:

```bash
cd backend
python run.py
```

Production requires PostgreSQL, a JWT secret of at least 32 characters, and
configured CORS origins. Render deployment is described in
[PRODUCTION_DEPLOYMENT.md](PRODUCTION_DEPLOYMENT.md), and operational
procedures are in [BACKEND_OPERATIONS.md](BACKEND_OPERATIONS.md).

The API includes customer authentication, medical profiles, remedy moderation,
orders, manual payment-proof handling, supplier/product management, and
the server-backed health chat, durable monthly chat quotas, and in-memory
per-IP rate limiting. Configure `LLM_BASE_URL`, `LLM_API_KEY`, and `LLM_MODEL`
on the backend only; these values must never be included in a Flutter build.
Non-Plus devices receive three chat requests per UTC calendar month. Rate
limits are configurable with the `RATE_LIMIT_*` environment variables.

## Product boundaries

The app is English-only for now. It does not include local demo catalogs,
customer-facing vendor selling screens, automatic payment processing, or
automatic medical diagnosis. Guidance is educational and does not replace
professional care.
