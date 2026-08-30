import '../models/remedy.dart';
import 'vector_index_service.dart';

class CheckResult {
  const CheckResult({
    required this.symptoms,
    required this.possibleCondition,
    required this.confidence,
    required this.remedies,
    this.isEmergency = false,
    this.emergencyReason,
  });

  final String symptoms;
  final String possibleCondition;
  final int confidence;
  final List<Remedy> remedies;
  final bool isEmergency;
  final String? emergencyReason;
}

class SymptomChecker {
  static const emergencyKeywords = [
    'chest pain',
    'kurwadza chipfuva',
    'kurwadza pachipfuva',
    'ukuhlaba esifubeni',
    'difficulty breathing',
    'kunzima ukuphefumula',
    'kunetsa kufema',
    'cannot breathe',
    'severe bleeding',
    'unconscious',
    'akaphaphami',
    'stroke',
    'seizure',
    'kubatwa nepfari',
    'ukuxhuzula',
    'suicidal',
    'poisoning',
  ];

  final EmbeddingServiceBase _embeddingService;
  final VectorIndexService _vectorIndex;
  bool _isInitialized = false;

  SymptomChecker({
    required EmbeddingServiceBase embeddingService,
    required VectorIndexService vectorIndex,
  })  : _embeddingService = embeddingService,
        _vectorIndex = vectorIndex;

  /// Initialize the symptom checker with a remedy catalog
  Future<void> initialize(List<Remedy> catalog) async {
    if (_isInitialized) return;

    await _embeddingService.initialize();
    await _vectorIndex.initialize();
    await _vectorIndex.buildIndex(catalog);
    _isInitialized = true;
  }

  /// Analyze symptoms using semantic matching
  Future<CheckResult> analyze(String input, List<Remedy> catalog) async {
    if (!_isInitialized) {
      await initialize(catalog);
    }

    final symptoms = input.trim();
    final normalized = symptoms.toLowerCase();

    // Check for emergency keywords first (fast, deterministic)
    final emergency = emergencyKeywords.firstWhere(
      (keyword) => normalized.contains(keyword),
      orElse: () => '',
    );
    if (emergency.isNotEmpty) {
      return CheckResult(
        symptoms: symptoms,
        possibleCondition: 'Urgent medical attention needed',
        confidence: 100,
        remedies: const [],
        isEmergency: true,
        emergencyReason:
            'Your message includes "$emergency". Please contact emergency services now.',
      );
    }

    try {
      // Use semantic search to find matching remedies
      final results = await _vectorIndex.search(
        symptoms,
        topK: 3,
        threshold: 0.2,
      );

      if (results.isEmpty) {
        return CheckResult(
          symptoms: symptoms,
          possibleCondition: 'General wellness concern',
          confidence: 0,
          remedies: const [],
        );
      }

      // Infer condition from top match
      final topMatch = results.first;
      final condition = _inferCondition(topMatch.$1, symptoms);
      final avgConfidence =
          (results.fold<int>(0, (sum, r) => sum + r.$2) ~/ results.length)
              .clamp(0, 100);

      return CheckResult(
        symptoms: symptoms,
        possibleCondition: condition,
        confidence: avgConfidence,
        remedies: results.map((r) => r.$1).toList(),
      );
    } catch (_) {
      // Fallback to keyword-based matching on error
      return _fallbackAnalyze(symptoms, catalog);
    }
  }

  /// Infer the condition from remedy and symptom text
  String _inferCondition(Remedy remedy, String symptoms) {
    final sLower = symptoms.toLowerCase();
    if (sLower.contains('head')) return 'Headache or migraine';
    if (sLower.contains('cough') || sLower.contains('throat')) {
      return 'Cold or respiratory symptoms';
    }
    if (sLower.contains('stomach') || sLower.contains('digest')) {
      return 'Digestive discomfort';
    }
    if (sLower.contains('allerg') || sLower.contains('itch')) {
      return 'Allergy or skin irritation';
    }
    if (sLower.contains('period') || sLower.contains('cramp')) {
      return 'Menstrual discomfort';
    }
    return remedy.category;
  }

  /// Fallback keyword-based matching if semantic search fails
  CheckResult _fallbackAnalyze(String symptoms, List<Remedy> catalog) {
    final normalized = symptoms.toLowerCase();

    String condition = 'General wellness concern';
    var confidence = 55;
    if (normalized.contains('headache') || normalized.contains('migraine')) {
      condition = 'Tension headache';
      confidence = 78;
    } else if (normalized.contains('cough') ||
        normalized.contains('sore throat')) {
      condition = 'Common cold symptoms';
      confidence = 76;
    } else if (normalized.contains('stomach') ||
        normalized.contains('nausea') ||
        normalized.contains('bloating')) {
      condition = 'Mild digestive discomfort';
      confidence = 73;
    } else if (normalized.contains('itch') ||
        normalized.contains('sneeze') ||
        normalized.contains('rash')) {
      condition = 'Allergy or skin irritation';
      confidence = 68;
    } else if (normalized.contains('period') || normalized.contains('cramp')) {
      condition = 'Menstrual discomfort';
      confidence = 70;
    }

    final matches = catalog
        .where(
          (remedy) =>
              remedy.tags.any(normalized.contains) ||
              remedy.category.toLowerCase().contains(
                    condition.toLowerCase().split(' ').first,
                  ),
        )
        .take(3)
        .toList();
    return CheckResult(
      symptoms: symptoms,
      possibleCondition: condition,
      confidence: matches.isEmpty ? 0 : confidence,
      remedies: matches,
    );
  }

  /// Dispose of resources
  void dispose() {
    _embeddingService.dispose();
    _vectorIndex.dispose();
  }
}


