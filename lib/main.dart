import 'dart:async';

import 'package:flutter/material.dart';

import 'l10n/localized.dart';
import 'models/remedy.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'services/app_store.dart';
import 'services/backend_api.dart';
import 'services/onnx_embedding_service.dart';
import 'services/remedy_catalog.dart';
import 'services/symptom_checker.dart';
import 'services/vendor_store.dart';
import 'services/vector_index_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Show splash immediately while data loads
  runApp(const SplashScreen());

  // Load store and remedies (fast, always works)
  final backendApi = BackendApi();
  final store = AppStore(backendApi: backendApi);
  await store.load();
  final vendorStore = VendorStore(backendApi: backendApi);
  await vendorStore.load();
  final remedies = await RemedyCatalog.load();

  // Initialize ML services — ONNX may fail on low-end devices,
  // so it falls back to keyword-based matching gracefully.
  final embeddingService = OnnxEmbeddingService();
  final vectorIndex = VectorIndexService(embeddingService);
  final checker = SymptomChecker(
    embeddingService: embeddingService,
    vectorIndex: vectorIndex,
  );

  // Pre-initialize ML in background (non-blocking). Keyword matching is used
  // until ONNX is ready or if the model cannot be loaded on this device.
  unawaited(checker.initialize(remedies));

  // Switch to the real app
  runApp(
    UsizoAiApp(
      store: store,
      vendorStore: vendorStore,
      remedies: remedies,
      checker: checker,
    ),
  );
}

class UsizoAiApp extends StatelessWidget {
  const UsizoAiApp({
    required this.store,
    required this.vendorStore,
    required this.remedies,
    required this.checker,
    super.key,
  });

  final AppStore store;
  final VendorStore vendorStore;
  final List<Remedy> remedies;
  final SymptomChecker checker;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xff087f70),
      brightness: Brightness.light,
    );
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) => Localized(
        languageCode: store.languageCode,
        child: MaterialApp(
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
          home: HomeScreen(
            store: store,
            vendorStore: vendorStore,
            remedies: remedies,
            checker: checker,
          ),
        ),
      ),
    );
  }
}


