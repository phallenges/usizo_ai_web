# Changelog

All notable changes to UsizoAI are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.2.2] - 2026-09-24

### Fixed

- Restored Plus activation token delivery. Render's free instance type blocks
  outbound traffic to SMTP ports 25, 465, and 587, so every approval failed with
  `Token email could not be sent.` Token email is now delivered over an HTTPS
  provider, auto-selected in the order `mailjet`, `brevo`, `sendgrid`, `smtp`;
  set `EMAIL_TRANSPORT` to pin one. Mailjet is first because it is the only
  free option found that accepts a Gmail sender without owning a domain. The
  SMTP settings still work on a paid instance type or when self-hosting.
- `GET /api/admin/plus-payment-submissions` now returns `deliveryEmail`, which
  the Plus Payments table reads. Rows showed `Missing` even when the app had
  stored the address.
- Approving a payment no longer fails on submissions without a delivery email:
  it falls back to the linked account's email, or returns a clear message
  instead of sending to an empty address.
- Approving a submission whose EcoCash reference already has an activation token
  returns HTTP 409 instead of issuing a second, unusable token.

### Added

- **Approve without email** in the Plus Payments table issues the token and
  shows it once so it can be handed over when email is unavailable; the approval
  response now reports the transport used.
- `POST /api/admin/email-test` and **Plus Tokens → Send test email** verify email
  delivery and surface the provider's own error message.
- Backend tests cover approval delivery, delivery failure, manual delivery,
  duplicate references, missing addresses, transport selection, and the email
  test endpoint.

### Notes

- Backend-only release. No Android rebuild is required, and `pubspec.yaml` is
  unchanged.

## [1.2.1] - 2026-09-23

### Security

- Device-scoped endpoints (`/api/devices/...`) now require the per-device
  `X-Device-Token` issued by `/api/devices/register`; a device id alone no
  longer grants access to medical profiles, orders, free checks, or Plus
  activation. Re-registering an existing device id requires its current
  token, and only the token's SHA-256 hash is stored server-side.
- Vendor- and customer-facing order payloads no longer include the owning
  device id, which is a credential for the endpoints above.
- Rate limiting now keys on the trusted (last) `X-Forwarded-For` entry
  appended by the reverse proxy, so rotating spoofed prefixes can no longer
  bypass limits; `/api/vendors/login` and `/api/admin/login` now use the
  strict auth bucket alongside `/api/auth/*`.
- Production refuses to boot without an explicit `SEED_SUPPLIER_PIN`
  instead of falling back to the placeholder `1234`.
- Fixed four client methods that sent a literal placeholder instead of the
  account/vendor `Bearer` token, silently failing authentication.
- Removed leftover Flutterwave test keys from the repository working tree.

### Client

- `backend_api.dart` stores and refreshes the device token, sends it on every
  device-scoped call, resets stale identities on 401/403, and single-flights
  registration so old installs recover automatically after updating.

## [1.1.1] - 2026-09-22

### Fixed

- Production supplier seed now normalizes the supplier phone number so
  `/vendor` sign-in works, migrates legacy rows stored with spaced phone
  numbers, and resets the supplier PIN on boot. The PIN defaults to `1234`
  and can be overridden with `SEED_SUPPLIER_PIN`.

## [1.1.0] - 2026-09-22

### Added

- Added a supplier web portal at `/vendor` for phone + PIN sign-in, product
  management with photo upload, order confirmation, EcoCash payment-proof
  review, and business profile editing.
- Added a vendor-scoped endpoint to view uploaded payment proofs.

### Changed

- Refreshed the native Flutter UI with a spruce, cream, and citrus visual
  system.
- Added a time-aware greeting on the home screen.
- Improved navigation-bar contrast for readability.
- Collapsed medical profile fields behind an explicit control.
- Cleared transient inputs after successful symptom checks, Plus submissions,
  token activation, and remedy submissions.
- Added automatic email delivery for approved Plus activation tokens.
- Added SMTP configuration and delivery-failure safeguards.

## [1.0.0] - 2026-09-19

### Added

- Flutter Android app with account setup and profile management.
- Educational symptom guidance with emergency prompts.
- Bundled remedy catalog and ONNX semantic matching with keyword fallback.
- Supplier marketplace with cart, orders, and manual EcoCash payment proof.
- Admin dashboard for users, orders, vendors, remedies, reviews, Plus payments,
  activation tokens, and audit events.
- FastAPI backend with PostgreSQL support and local SQLite test mode.
- UsizoAI landing page, favicon, Android release download, and Render
  deployment configuration.

### Notes

- EcoCash payments are manually verified.
- Plus activation tokens are single-use.
- Health guidance is educational and does not replace professional care.
- The current main branch does not include a general-purpose LLM chat.
