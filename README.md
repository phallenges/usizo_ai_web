# UsizoAI

UsizoAI is a Flutter Android app and FastAPI service for educational health
guidance, emergency-care prompts, community wellness knowledge, and a manual
EcoCash marketplace flow. The current `main` branch uses the bundled remedy
catalog and on-device semantic matching; it does not require an LLM or an
online connection for symptom guidance.

UsizoAI is not a medical diagnosis service and does not replace a qualified
health professional.

## Current product flow

- **Guidance:** Users describe symptoms in their own words. Emergency keywords
  are intercepted before regular matching. Other inputs are matched against
  the bundled remedy catalog with ONNX embeddings and a keyword fallback.
- **Free usage:** Non-Plus users receive three symptom checks per device
  before the Plus upgrade prompt.
- **Accounts:** Users create an account with email or phone, then their account,
  device, profile, and order data can synchronize with the API.
- **Plus:** A user pays manually through EcoCash, submits the EcoCash reference
  and confirmation message in the app, and provides an email for delivery.
  An admin verifies the payment and approves it in the dashboard. The backend
  generates a single-use token and emails it automatically.
- **Marketplace:** Users choose a supplier, browse products when available,
  create an order, pay the supplier externally, and upload payment proof for
  supplier verification.
- **Admin:** The operations dashboard supports users, orders, vendors, remedy
  moderation, reviews, Plus payment confirmations, activation tokens, and
  audit events.

## Repository layout

```text
lib/                         Flutter application
lib/screens/                 Customer screens and flows
lib/services/                API, catalog, payment, and matching services
lib/services/app_updater.dart In-app APK update download and install bridge
assets/remedies.json         Bundled remedy catalog
assets/models/               ONNX embedding model
backend/app/                 FastAPI application and database layer
backend/app/static/admin.html Operations dashboard
backend/tests/               Backend API tests
render.yaml                  Render web service and PostgreSQL blueprint
```

## Run locally

### Flutter app

```powershell
flutter pub get
flutter analyze
flutter run
```

The app defaults to the public API origin configured in
`lib/services/backend_api.dart`. Override it for another environment:

```powershell
flutter run --dart-define=USIZO_API_BASE_URL=http://127.0.0.1:3000
```

### Backend

```powershell
cd backend
py -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
py run.py
```

The development API runs at `http://127.0.0.1:3000`. Configure a development
`.env` from `backend/.env.example`. SQLite is suitable for local development;
production uses PostgreSQL.

### Backend tests

```powershell
backend\.venv\Scripts\python.exe -m pytest -q backend\tests
```

## Android updates

The app asks `/api/app/version` after launch. When a newer release exists it
offers a one-tap update that downloads the APK in the background, shows
progress, and opens the Android installer. Android still requires the person to
confirm the install; see
[PRODUCTION_DEPLOYMENT.md](PRODUCTION_DEPLOYMENT.md) for the release,
`versionCode`, and signing-key rules.

## Deployment

Render deployment, environment variables, email delivery, database requirements,
health checks, and release procedures are documented in
[PRODUCTION_DEPLOYMENT.md](PRODUCTION_DEPLOYMENT.md).

Operational procedures and the customer/admin payment flow are documented in
[BACKEND_OPERATIONS.md](BACKEND_OPERATIONS.md).

## Public service routes

The deployed service exposes:

```text
GET /             Landing page
GET /admin/       Admin dashboard
GET /vendor/      Supplier portal
GET /health       Health check
GET /api/         API status
GET /download     Redirect to the current Android APK
GET /api/app/version  Latest APK version and update status
GET /favicon.png  Website favicon
```

The current Render service is:

```text
https://usizoai.onrender.com
```

## Product boundaries

The current main branch is English-first. It does not include automatic
EcoCash payment verification, card processing, automatic vendor payouts,
automatic medical diagnosis, or a general-purpose chatbot. Payment references
are reviewed manually, and all health guidance is educational.
