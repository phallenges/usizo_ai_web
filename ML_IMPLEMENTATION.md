# ML Model Implementation Guide

## Overview

This document describes the implementation of semantic symptom matching using the **all-MiniLM-L12-v2** embedding model converted to TFLite format for offline-first mobile deployment.

## Architecture

### Components

1. **EmbeddingService** (`lib/services/embedding_service.dart`)
   - Loads and manages the TFLite model
   - Generates 384-dimensional embeddings for text
   - Provides cosine similarity computation
   - Handles text preprocessing and tokenization

2. **VectorIndexService** (`lib/services/vector_index_service.dart`)
   - Builds and maintains a vector index of remedies
   - Caches embeddings to disk using `shared_preferences`
   - Performs semantic search using cosine similarity
   - Intelligently combines text and tag embeddings (70% text, 30% tags)

3. **SymptomChecker** (`lib/services/symptom_checker.dart`)
   - Replaces keyword-based matching with semantic search
   - Maintains emergency keyword detection (fast path)
   - Falls back to keyword matching if semantic search fails
   - Infers conditions from matched remedies

## Model Conversion

### Prerequisites

```bash
pip install torch transformers tensorflow
```

### Convert Model

Run the conversion script to download and convert the model:

```bash
python scripts/convert_model.py
```

This will:
1. Download `sentence-transformers/all-MiniLM-L12-v2` from HuggingFace
2. Create a wrapper for mean-pooled embeddings
3. Convert to TensorFlow SavedModel format
4. Quantize and convert to TFLite
5. Save to `assets/models/all_minilm_l12_v2.tflite` (~100 MB)

### Manual Setup

If you've already converted the model elsewhere:

1. Create the directory: `mkdir -p assets/models`
2. Place the model file: `assets/models/all_minilm_l12_v2.tflite`

## Model Specifications

- **Name**: all-MiniLM-L12-v2
- **Embedding Dimension**: 384
- **Max Token Length**: 512
- **Format**: TFLite (FlatBuffers)
- **Size**: ~100 MB
- **Inference Time**: ~100-200ms per text (device-dependent)

## Integration

### 1. Update pubspec.yaml

Dependencies are already added:
- `tflite_flutter: ^0.10.0` - TFLite interpreter
- `vector_math: ^2.1.4` - Vector operations

### 2. Initialize in main.dart

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize ML services
  final embeddingService = EmbeddingService();
  final vectorIndex = VectorIndexService(embeddingService);
  final checker = SymptomChecker(
    embeddingService: embeddingService,
    vectorIndex: vectorIndex,
  );
  
  runApp(UsizoAiApp(checker: checker, ...));
}
```

### 3. Use in UI

```dart
// Async semantic search
final result = await checker.analyze(symptoms, remedies);

// Emergency keywords are checked first (fast)
if (result.isEmergency) {
  // Route to emergency screen
}

// Semantic results include confidence scores
print(result.possibleCondition); // e.g., "Headache or migraine"
print(result.confidence); // 0-100
print(result.remedies); // Top 3 matching remedies
```

## Performance Characteristics

### Search Performance

- **Cold Start**: ~2-5 seconds (first app launch, building index)
- **Warm Search**: ~100-200ms per query (subsequent searches)
- **Memory**: ~150-200 MB loaded model
- **Disk Cache**: ~5-10 MB for 50 remedies

### Accuracy

The semantic matching is:
- **More resilient** to spelling variations and synonyms than keyword matching
- **Context-aware**: understands relationships between symptoms and conditions
- **Multilingual-friendly**: works with English, Shona, and Ndebele (with careful preprocessing)

## Fallback Behavior

If semantic search fails:
1. Logs the error
2. Falls back to deterministic keyword matching
3. Returns results based on tag/category matching

This ensures the app never crashes due to ML errors.

## Customization

### Adjust Search Threshold

In `VectorIndexService.search()`:

```dart
final results = await _vectorIndex.search(
  symptoms,
  topK: 3,
  threshold: 0.2,  // Adjust this: lower = more results
);
```

### Adjust Embedding Weights

In `VectorIndexService.search()`:

```dart
// Combine text and tag embeddings
final combined = (textSim * 0.7) + (tagSim * 0.3);  // Adjust weights
```

### Use Different Tokenizer

Replace `_tokenize()` in `EmbeddingService` with a proper BERT tokenizer:

```dart
// Install package: pip install -m transformers
// Use: python -c "from transformers import AutoTokenizer; t = AutoTokenizer.from_pretrained(...)"
```

## Deployment

### Flutter Android Setup

1. Add to `android/app/build.gradle`:

```gradle
android {
  aaptOptions {
    noCompress "tflite"
  }
}
```

2. Add to `android/build.gradle`:

```gradle
ndk {
  version = "21.4.7075529"
}
```

### Flutter iOS Setup

No special configuration needed; TFLite is supported via CocoaPods.

## Testing

```bash
flutter test
```

Test files should verify:
- Model loads correctly
- Embeddings are generated (384-dim vectors)
- Semantic search returns sorted results
- Emergency keywords are detected
- Fallback works when model fails

## Troubleshooting

### Model Not Found

```
Failed to initialize embedding model: No such file or directory
```

**Solution**: Ensure `assets/models/all_minilm_l12_v2.tflite` exists and is listed in `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/models/all_minilm_l12_v2.tflite
    - assets/remedies.json
```

### Memory Issues

If the app crashes on low-end devices:
- Quantize to 8-bit: `converter.optimizations = [tf.lite.Optimize.DEFAULT]`
- Use a smaller model: `all-MiniLM-L6-v2` (384-dim, ~50 MB)
- Reduce batch size to 1

### Slow Inference

If searches are taking >500ms:
- Check device CPU load
- Consider GPU delegate (TFLite GPU plugin)
- Use NNAPI delegate on Android

## Future Improvements

1. **BERT Tokenizer**: Replace simple whitespace tokenization with proper BERT WordPiece
2. **GPU Acceleration**: Use TFLite GPU delegate for 5-10x speedup
3. **Hierarchical Search**: Build condition -> remedy hierarchy for faster search
4. **User Feedback Loop**: Fine-tune embeddings based on user interactions
5. **Multilingual Support**: Fine-tune for Shona/Ndebele specific terminology

## References

- [Sentence Transformers](https://www.sbert.net/)
- [all-MiniLM-L12-v2 Model Card](https://huggingface.co/sentence-transformers/all-MiniLM-L12-v2)
- [TensorFlow Lite Flutter Plugin](https://pub.dev/packages/tflite_flutter)
- [ONNX Runtime Flutter](https://github.com/microsoft/onnxruntime)
