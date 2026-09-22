# Changelog

All notable changes to UsizoAI are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

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
