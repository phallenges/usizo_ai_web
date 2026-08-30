// Example: How to use the new ML-powered SymptomChecker

import 'package:flutter/material.dart';
import 'lib/services/embedding_service.dart';
import 'lib/services/vector_index_service.dart';
import 'lib/services/symptom_checker.dart';
import 'lib/models/remedy.dart';

void exampleUsage() async {
  // Step 1: Initialize services
  final embeddingService = EmbeddingService();
  final vectorIndex = VectorIndexService(embeddingService);
  final checker = SymptomChecker(
    embeddingService: embeddingService,
    vectorIndex: vectorIndex,
  );

  // Step 2: Load remedies
  final remedies = <Remedy>[
    // Your remedy list from assets/remedies.json
  ];

  // Step 3: Initialize (builds the vector index)
  await checker.initialize(remedies);

  // Step 4: Analyze symptoms
  final result = await checker.analyze(
    "I have a mild headache and nausea",
    remedies,
  );

  // Step 5: Use results
  print('Condition: ${result.possibleCondition}');
  print('Confidence: ${result.confidence}%');
  print('Remedies found: ${result.remedies.length}');

  for (final remedy in result.remedies) {
    print('  - ${remedy.name} (${remedy.category})');
  }

  // Step 6: Cleanup
  checker.dispose();
}

// Example: Direct embedding generation
void exampleEmbedding() async {
  final service = EmbeddingService();
  await service.initialize();

  // Generate embedding for symptom text
  final embedding1 = await service.embed("I have a headache");
  print('Embedding dimension: ${embedding1.length}'); // 384

  final embedding2 = await service.embed("My head hurts");
  print('Embedding dimension: ${embedding2.length}'); // 384

  // Compute similarity (should be high, they're synonymous)
  final similarity = EmbeddingService.cosineSimilarity(embedding1, embedding2);
  print('Similarity: $similarity'); // ~0.8-0.9

  service.dispose();
}

// Example: Direct vector index usage
void exampleVectorIndex() async {
  final embeddingService = EmbeddingService();
  await embeddingService.initialize();

  final vectorIndex = VectorIndexService(embeddingService);
  await vectorIndex.initialize();

  final remedies = <Remedy>[
    // Your remedies
  ];

  // Build index (generates embeddings for all remedies)
  await vectorIndex.buildIndex(remedies);

  // Search for similar remedies
  final results = await vectorIndex.search(
    "I feel nauseous after eating",
    topK: 3,
    threshold: 0.2,
  );

  for (final (remedy, score) in results) {
    print('${remedy.name}: ${score}%');
  }

  vectorIndex.dispose();
}

// Example: Flutter UI with loading state
class SymptomCheckerExample extends StatefulWidget {
  @override
  _SymptomCheckerExampleState createState() => _SymptomCheckerExampleState();
}

class _SymptomCheckerExampleState extends State<SymptomCheckerExample> {
  final controller = TextEditingController();
  CheckResult? result;
  bool isChecking = false;

  void checkSymptoms() async {
    setState(() => isChecking = true);

    try {
      final checker = SymptomChecker(
        embeddingService: EmbeddingService(),
        vectorIndex: VectorIndexService(EmbeddingService()),
      );

      // Simulate getting remedies
      final remedies = <Remedy>[];

      final checked = await checker.analyze(controller.text, remedies);

      if (mounted) {
        setState(() {
          result = checked;
          isChecking = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() => isChecking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          TextField(
            controller: controller,
            enabled: !isChecking,
            decoration: InputDecoration(
              hintText: 'Describe your symptoms...',
            ),
          ),
          FilledButton(
            onPressed: isChecking ? null : checkSymptoms,
            child: isChecking
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('Analyze'),
          ),
          if (result != null) ...[
            Text('Condition: ${result!.possibleCondition}'),
            Text('Confidence: ${result!.confidence}%'),
            for (final remedy in result!.remedies)
              ListTile(title: Text(remedy.name)),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
