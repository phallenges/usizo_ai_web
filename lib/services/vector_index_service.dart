import 'package:shared_preferences/shared_preferences.dart';

import '../models/remedy.dart';

/// Generic embedding service interface
abstract class EmbeddingServiceBase {
  Future<void> initialize();
  Future<List<double>> embed(String text);
  void dispose();
  static double cosineSimilarity(List<double> a, List<double> b) => 0.0;
}

/// Represents an indexed remedy with precomputed embeddings
class IndexedRemedy {
  const IndexedRemedy({
    required this.remedy,
    required this.embedding,
    required this.textEmbedding,
  });

  final Remedy remedy;
  final List<double> embedding;
  final List<double> textEmbedding;

  /// Encode embeddings to string for storage
  String encode() {
    final combined = [...embedding, ...textEmbedding];
    return combined.map((v) => v.toStringAsFixed(6)).join(',');
  }

  /// Decode embeddings from string
  static IndexedRemedy decode(Remedy remedy, String encoded) {
    const embeddingDim = 384;
    final values =
        encoded.split(',').map((v) => double.tryParse(v) ?? 0.0).toList();
    return IndexedRemedy(
      remedy: remedy,
      embedding: values.sublist(0, embeddingDim),
      textEmbedding: values.sublist(embeddingDim),
    );
  }
}

/// Service for managing and searching remedy embeddings
class VectorIndexService {
  static const _cacheKeyPrefix = 'remedy_embedding_';
  static const _indexVersionKey = 'remedy_index_version';
  static const _currentVersion = 3; // Bumped for ONNX model

  final EmbeddingServiceBase _embeddingService;
  late SharedPreferences _prefs;
  Map<String, IndexedRemedy> _cache = {};
  bool _isInitialized = false;

  VectorIndexService(this._embeddingService);

  /// Initialize the vector index, loading cached embeddings
  Future<void> initialize() async {
    if (_isInitialized) return;

    _prefs = await SharedPreferences.getInstance();
    _isInitialized = true;
  }

  /// Build or rebuild the index for a catalog of remedies
  Future<void> buildIndex(List<Remedy> catalog) async {
    if (!_isInitialized) {
      await initialize();
    }

    await _embeddingService.initialize();

    final storedVersion = _prefs.getInt(_indexVersionKey) ?? 0;
    if (storedVersion == _currentVersion && _isCacheValid(catalog)) {
      await _loadFromCache(catalog);
      return;
    }

    _cache.clear();
    for (final remedy in catalog) {
      try {
        final combinedText =
            '${remedy.name} ${remedy.description} ${remedy.category} ${remedy.tags.join(" ")}';
        final embedding = await _embeddingService.embed(combinedText);
        final tagText = remedy.tags.join(' ');
        final tagEmbedding = await _embeddingService.embed(tagText);

        final indexed = IndexedRemedy(
          remedy: remedy,
          embedding: embedding,
          textEmbedding: tagEmbedding,
        );
        _cache[remedy.id] = indexed;

        // Cache to disk
        final key = '$_cacheKeyPrefix${remedy.id}';
        await _prefs.setString(key, indexed.encode());
      } catch (_) {
        // Silently skip remedies that fail to index
      }
    }

    await _prefs.setInt(_indexVersionKey, _currentVersion);
  }

  /// Search for remedies similar to a symptom description
  /// Returns list of (remedy, similarity score) tuples, sorted by relevance
  Future<List<(Remedy, int)>> search(
    String symptoms, {
    int topK = 3,
    double threshold = 0.2,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final queryEmbedding = await _embeddingService.embed(symptoms);

      final scored = <(Remedy, double)>[];

      for (final indexed in _cache.values) {
        // Combine text and tag embeddings for better matching
        final textSim = _cosineSimilarity(queryEmbedding, indexed.embedding);
        final tagSim =
            _cosineSimilarity(queryEmbedding, indexed.textEmbedding);
        final combined = (textSim * 0.7) + (tagSim * 0.3);

        if (combined >= threshold) {
          scored.add((indexed.remedy, combined));
        }
      }

      scored.sort((a, b) => b.$2.compareTo(a.$2));
      return scored.take(topK).map((s) => (s.$1, (s.$2 * 100).toInt())).toList();
    } catch (_) {
      return [];
    }
  }

  /// Compute cosine similarity
  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;

    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    normA = normA > 0 ? normA : 1.0;
    normB = normB > 0 ? normB : 1.0;
    return dotProduct / (normA.sqrt * normB.sqrt);
  }

  /// Check if cache is still valid for the current catalog
  bool _isCacheValid(List<Remedy> catalog) {
    for (final remedy in catalog) {
      if (!_cache.containsKey(remedy.id)) {
        return false;
      }
    }
    return _cache.length == catalog.length;
  }

  /// Load cached embeddings from disk
  Future<void> _loadFromCache(List<Remedy> catalog) async {
    _cache.clear();
    for (final remedy in catalog) {
      final key = '$_cacheKeyPrefix${remedy.id}';
      final encoded = _prefs.getString(key);
      if (encoded != null) {
        try {
          _cache[remedy.id] = IndexedRemedy.decode(remedy, encoded);
        } catch (_) {
          // Silently skip cache entries that fail to decode
        }
      }
    }
  }

  /// Clear the index cache
  Future<void> clearCache() async {
    if (!_isInitialized) {
      await initialize();
    }

    _cache.clear();
    final keys = _prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith(_cacheKeyPrefix)) {
        await _prefs.remove(key);
      }
    }
    await _prefs.remove(_indexVersionKey);
  }

  /// Dispose of resources
  void dispose() {
    _cache.clear();
    _embeddingService.dispose();
  }
}
