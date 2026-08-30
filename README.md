# UsizoAI

UsizoAI is an offline-first Flutter Material 3 demo for practical symptom
guidance, emergency interception, a mocked wellness marketplace, profile
settings, and a freemium experience.

## Run

Install Flutter, then from this directory run:

```bash
flutter pub get
flutter analyze
flutter run
```

The app ships with `assets/remedies.json`, containing 50 structured Zimbabwean
and Southern African remedy records with scientific names, local names,
preparation, dosage, safety, evidence source, and study links. Symptom matching
and emergency interception are local and do not require a network connection or
API key.

## ML Model

The symptom matching has been upgraded to use **semantic embeddings** with the
**all-MiniLM-L12-v2** model converted to TFLite for offline inference.

### Quick Start

Before running the app, convert and bundle the model:

```bash
python scripts/convert_model.py
```

This generates `assets/models/all_minilm_l12_v2.tflite` (~100 MB).

See [ML_IMPLEMENTATION.md](ML_IMPLEMENTATION.md) for full details on:
- Model architecture and performance
- Custom tokenization and search tuning
- Android/iOS deployment setup
- Troubleshooting and optimization

### How It Works

1. **Semantic Matching**: User input is converted to a 384-dimensional embedding
2. **Vector Search**: Remedies are searched by semantic similarity, not keywords
3. **Adaptive Ranking**: Results combine text relevance (70%) and tag relevance (30%)
4. **Fallback Safety**: If ML fails, the app falls back to keyword matching
5. **Offline First**: No network required; all embeddings computed locally

### Key Improvements Over Keyword Matching

- ✅ **Synonym-aware**: "migraine" matches "tension headache"
- ✅ **Context-sensitive**: understands relationships between symptoms
- ✅ **Typo-tolerant**: handles spelling variations
- ✅ **Multilingual-ready**: works with English, Shona, Ndebele embeddings

## Product notes

- Three symptom checks are available by default. The Plus switch is a local
  demo toggle, persisted with `shared_preferences`.
- English, Shona, and Ndebele emergency phrases are intercepted before matching.
- The symptom matcher now uses semantic embeddings via all-MiniLM-L12-v2 (TFLite).
  Remedy catalog is indexed on app start and cached to disk.
- Marketplace basket and checkout are intentionally mocked and never collect
  payment.
- Emergency keywords route to an urgent-help screen. The dialer integration
  is a safe stub; production can inject `url_launcher` or a native adapter.
- `integration_stubs.dart` provides credential-gated AI and payment interfaces
  without making network calls in the demo.
- Guidance is educational only and must not replace professional care.

