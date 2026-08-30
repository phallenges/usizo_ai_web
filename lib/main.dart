import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'models/remedy.dart';
import 'services/app_store.dart';
import 'services/onnx_embedding_service.dart';
import 'services/remedy_catalog.dart';
import 'services/symptom_checker.dart';
import 'services/vector_index_service.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env.local');
  final store = AppStore();
  await store.load();
  final remedies = await RemedyCatalog.load();

  // Initialize production ML services with ONNX Runtime
  final embeddingService = OnnxEmbeddingService();
  final vectorIndex = VectorIndexService(embeddingService);
  final checker = SymptomChecker(
    embeddingService: embeddingService,
    vectorIndex: vectorIndex,
  );

  runApp(UsizoAiApp(
    store: store,
    remedies: remedies,
    checker: checker,
  ));
}

class UsizoAiApp extends StatelessWidget {
  const UsizoAiApp({
    required this.store,
    required this.remedies,
    required this.checker,
    super.key,
  });

  final AppStore store;
  final List<Remedy> remedies;
  final SymptomChecker checker;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xff087f70),
      brightness: Brightness.light,
    );
    return MaterialApp(
      title: 'UsizoAI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xfff7faf9),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      home: HomeScreen(store: store, remedies: remedies, checker: checker),
    );
  }
}


