# ML Implementation - Testing Guide

## Setup Checklist

- [ ] **Convert Model**: Run `python scripts/convert_model.py` to generate `assets/models/all_minilm_l12_v2.tflite`
- [ ] **Install Dependencies**: Run `flutter pub get`
- [ ] **Analyze Code**: Run `flutter analyze` (should pass)
- [ ] **Run App**: Run `flutter run`

## Testing Scenarios

### 1. Cold Start (First Launch)

**What happens**:
- App loads remedies from `assets/remedies.json`
- SymptomChecker initializes EmbeddingService (loads TFLite model)
- VectorIndexService builds embeddings for all 50 remedies
- Results are cached to SharedPreferences

**What to expect**:
- First symptom check takes 2-5 seconds (building index)
- "Analyzing..." progress indicator shows
- No crashes, fallback works if model fails

### 2. Semantic Matching Accuracy

Test these symptom queries:

| Input | Expected Condition | Expected Remedies |
|-------|-------------------|-------------------|
| "I have a headache" | Headache or migraine | Ginger tea, etc. |
| "My throat is sore" | Cold or respiratory | Saline spray, etc. |
| "Stomach feels off" | Digestive discomfort | Ginger tea, etc. |
| "Itchy, can't stop" | Allergy or skin irritation | Related salves |
| "Cramps" | Menstrual discomfort | Pain relief, etc. |

### 3. Emergency Detection

Test these emergency phrases:

```
"chest pain" → Emergency Screen
"difficulty breathing" → Emergency Screen
"unconscious" → Emergency Screen
"kurwadza chipfuva" (Shona) → Emergency Screen
"ukuhlaba esifubeni" (Ndebele) → Emergency Screen
```

**What to expect**: 
- Routes immediately to emergency screen
- Bypasses semantic search (fast path)
- Confidence = 100%

### 4. Fallback Behavior

To test fallback without breaking the model:
1. Temporarily rename `assets/models/all_minilm_l12_v2.tflite` to `.backup`
2. Run the app
3. Symptom checks should still work using keyword matching

### 5. Cache Validation

1. First run: Close app after a symptom check
2. Reopen app: Subsequent checks should be <200ms (warm cache)
3. Verify in SharedPreferences: `remedies_index_version` should be 2

## Performance Benchmarks

### Expected Timings

| Operation | Time |
|-----------|------|
| Model Load (first time) | 1-2 seconds |
| Index Build (50 remedies) | 2-5 seconds |
| Semantic Search (warm) | 100-200ms |
| Embedding Generation | ~50ms per text |

### Device Performance

Varies by:
- CPU cores/speed
- RAM available
- Device age (newer = faster)

**Minimum supported**: ARMv7 (32-bit Android 5.0+), iPhone 6s+

## Debugging

### Check Model Loading

In `embedding_service.dart`, add logs:

```dart
print("Model size: ${_interpreter.getOutputTensors().length}");
```

### Check Embeddings

In `vector_index_service.dart`:

```dart
print("Generated embedding dimension: ${embedding.length}");
print("First 10 values: ${embedding.sublist(0, 10)}");
```

### Check Cache

In SharedPreferences:

```dart
final prefs = await SharedPreferences.getInstance();
prefs.getKeys().forEach((key) {
  if (key.startsWith('remedy_embedding_')) {
    print("Cached: $key");
  }
});
```

## Common Issues & Solutions

### Issue: "Failed to initialize embedding model"

**Cause**: Model file not found or not included in assets

**Solution**:
```bash
# Generate model
python scripts/convert_model.py

# Verify file exists
ls -la assets/models/all_minilm_l12_v2.tflite

# Ensure pubspec.yaml includes it
```

### Issue: "out of memory" on low-end device

**Cause**: Model is ~100 MB, might be too large for <2GB RAM

**Solution**:
- Use smaller model: `all-MiniLM-L6-v2` (~50 MB)
- Quantize to 8-bit
- Limit embeddings to batch of 10 remedies at a time

### Issue: Searches taking >500ms

**Cause**: Device CPU overloaded or slow inference

**Solution**:
- Use GPU delegate (needs TFLite GPU plugin)
- Test on faster device
- Check if other apps running

### Issue: Crashes on emoji/special characters

**Cause**: Simple tokenizer doesn't handle Unicode well

**Solution**:
- Upgrade tokenizer to BERT WordPiece
- Add string sanitization in `_preprocessText()`

## Next Steps for Production

1. **Replace simple tokenizer** with proper BERT tokenizer
2. **Add GPU delegate** for 5-10x speedup
3. **Fine-tune embeddings** on local symptom/remedy pairs
4. **Add model versioning** to auto-update when new model available
5. **Implement hierarchical search** for faster queries
6. **Add analytics** to track search quality and fallback rate
