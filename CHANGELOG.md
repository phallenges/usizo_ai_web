# Changelog

All notable changes to UsizoAI are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.0.0] - 2026-08-30

### Added
- Offline symptom guidance with semantic embedding search (all-MiniLM-L12-v2 via ONNX Runtime).
- Emergency keyword interception in English, Shona, and Ndebele.
- Fallback to keyword-based matching when the ML model is unavailable.
- Wellness marketplace with mocked basket and Flutterwave checkout.
- Freemium toggle persisted with shared_preferences (3 free checks).
- Profile screen with editable user details.
- Vector index cached to disk for fast subsequent lookups.
- Model conversion script (`scripts/convert_model.py`).
- Remedy catalog (`assets/remedies.json`) with 50 Southern African remedies.
