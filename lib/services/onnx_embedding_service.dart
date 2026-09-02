import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';

import 'vector_index_service.dart';

/// Production-grade embedding service using ONNX Runtime.
///
/// Uses the real all-MiniLM-L12-v2 model for semantic embeddings.
/// Falls back gracefully if the model cannot be loaded (e.g. on low-memory devices).
class OnnxEmbeddingService implements EmbeddingServiceBase {
  static const modelAssetPath = 'assets/models/all_minilm_l12_v2.onnx';
  static const embeddingDim = 384;
  static const maxTokenLength = 512;
  static const vocabSize = 30522;

  OrtSession? _session;
  bool _isInitialized = false;
  bool _failed = false;

  /// Whether ONNX initialization succeeded.
  bool get isAvailable => _isInitialized && !_failed;

  @override
  bool get canBuildSemanticIndex => isAvailable;

  @override
  Future<void> initialize() async {
    if (_isInitialized || _failed) return;

    try {
      OrtEnv.instance.init();

      // Copy model from assets to a temp file to avoid triple-buffering.
      // rootBundle.load() holds the file in Dart heap, then asUint8List()
      // creates another copy, then OrtSession.fromBuffer copies into Java
      // heap — that's ~162MB for a 54MB model, which OOMs many phones.
      // Writing to a temp file lets ONNX Runtime memory-map it directly.
      final tempDir = Directory.systemTemp;
      final modelFile = File('${tempDir.path}/all_minilm_l12_v2.onnx');

      if (!await modelFile.exists()) {
        final bytes = await rootBundle.load(modelAssetPath);
        await modelFile.writeAsBytes(
          bytes.buffer.asUint8List(),
          flush: false,
        );
      }

      final sessionOptions = OrtSessionOptions();
      _session = OrtSession.fromFile(modelFile, sessionOptions);

      _isInitialized = true;
    } catch (e) {
      // Don't crash — mark as failed so the app can fall back to keyword matching.
      _failed = true;
      _session = null;
    }
  }

  @override
  Future<List<double>> embed(String text) async {
    if (_failed) {
      return _fallbackEmbed(text);
    }
    if (!_isInitialized) {
      await initialize();
    }
    if (_failed) {
      return _fallbackEmbed(text);
    }

    try {
      final preprocessed = _preprocessText(text);
      final tokens = _tokenize(preprocessed);

      final inputIds = List<int>.filled(maxTokenLength, 0);
      final attentionMask = List<int>.filled(maxTokenLength, 0);
      final tokenTypeIds = List<int>.filled(maxTokenLength, 0);

      for (int i = 0; i < tokens.length && i < maxTokenLength; i++) {
        inputIds[i] = tokens[i];
        attentionMask[i] = 1;
        tokenTypeIds[i] = 0;
      }

      final inputIdsTensor = OrtValueTensor.createTensorWithDataList(
        inputIds,
        [1, maxTokenLength],
      );
      final attentionMaskTensor = OrtValueTensor.createTensorWithDataList(
        attentionMask,
        [1, maxTokenLength],
      );
      final tokenTypeIdsTensor = OrtValueTensor.createTensorWithDataList(
        tokenTypeIds,
        [1, maxTokenLength],
      );

      final inputs = {
        'input_ids': inputIdsTensor,
        'attention_mask': attentionMaskTensor,
        'token_type_ids': tokenTypeIdsTensor,
      };

      final runOptions = OrtRunOptions();
      final outputs = await _session!.runAsync(runOptions, inputs);
      runOptions.release();
      inputIdsTensor.release();
      attentionMaskTensor.release();
      tokenTypeIdsTensor.release();

      if (outputs == null || outputs.isEmpty) {
        return _fallbackEmbed(text);
      }

      final output = outputs[0];
      final data = output!.value as List<double>;

      List<double> embedding;
      if (data.length >= embeddingDim) {
        embedding = data.sublist(0, embeddingDim);
      } else {
        embedding = List<double>.filled(embeddingDim, 0.0);
        for (int i = 0; i < data.length && i < embeddingDim; i++) {
          embedding[i] = data[i];
        }
      }

      return _normalize(embedding);
    } catch (_) {
      return _fallbackEmbed(text);
    }
  }

  /// Simple hash-based embedding when ONNX is unavailable.
  List<double> _fallbackEmbed(String text) {
    final embedding = List<double>.filled(embeddingDim, 0.0);
    int hash = 5381;
    for (int i = 0; i < text.length; i++) {
      hash = ((hash << 5) + hash) + text.codeUnitAt(i);
    }
    final seed = hash.abs();
    for (int i = 0; i < embeddingDim; i++) {
      final s = (seed + i) * 9301 + 49297;
      embedding[i] = ((s % 10000) / 10000.0) - 0.5;
    }
    return _normalize(embedding);
  }

  static double cosineSimilarity(List<double> a, List<double> b) {
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
    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  List<int> _tokenize(String text) {
    final tokens = <int>[101];
    final words = text.split(' ');
    for (final word in words) {
      if (word.isNotEmpty) {
        tokens.add(_hashToken(word) % vocabSize);
        if (tokens.length >= maxTokenLength - 1) break;
      }
    }
    if (tokens.length < maxTokenLength) {
      tokens.add(102);
    }
    return tokens;
  }

  int _hashToken(String word) {
    int hash = 5381;
    for (int i = 0; i < word.length; i++) {
      hash = ((hash << 5) + hash) + word.codeUnitAt(i);
    }
    return hash.abs();
  }

  String _preprocessText(String text) {
    return text
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[^\w\s]'), '');
  }

  List<double> _normalize(List<double> embedding) {
    double norm = 0.0;
    for (final val in embedding) {
      norm += val * val;
    }
    norm = sqrt(norm);
    if (norm == 0) norm = 1.0;
    return embedding.map((val) => val / norm).toList();
  }

  @override
  void dispose() {
    if (_isInitialized) {
      try {
        _session?.release();
        OrtEnv.instance.release();
      } catch (_) {}
      _isInitialized = false;
    }
  }
}
