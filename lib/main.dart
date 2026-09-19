import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n/localized.dart';
import 'models/remedy.dart';
import 'screens/app_tour_screen.dart';
import 'screens/account_setup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'services/app_store.dart';
import 'services/backend_api.dart';
import 'services/onnx_embedding_service.dart';
import 'services/remedy_catalog.dart';
import 'services/symptom_checker.dart';
import 'services/vector_index_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Show splash immediately while data loads
  runApp(const SplashScreen());

  // Load store and remedies (fast, always works)
  final backendApi = BackendApi();
  final store = AppStore(backendApi: backendApi);
  await store.load();
  final remedies = await RemedyCatalog.load();
  final contributedRemedies = await backendApi.fetchApprovedRemedies();
  final allRemedies = [...remedies, ...contributedRemedies];

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
  unawaited(checker.initialize(allRemedies));

  // Switch to the real app
  runApp(
    UsizoAiApp(
      store: store,
      remedies: allRemedies,
      checker: checker,
      tourComplete: (await SharedPreferences.getInstance())
              .getBool(AppTourScreen.completedKey) ??
          false,
      accountReady: await backendApi.hasAccount(),
    ),
  );
}

class UsizoAiApp extends StatelessWidget {
  const UsizoAiApp({
    required this.store,
    required this.remedies,
    required this.checker,
    required this.tourComplete,
    required this.accountReady,
    super.key,
  });

  final AppStore store;
  final List<Remedy> remedies;
  final SymptomChecker checker;
  final bool tourComplete;
  final bool accountReady;

  @override
  Widget build(BuildContext context) {
    const forest = Color(0xff153f36);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: forest,
      brightness: Brightness.light,
      surface: const Color(0xfff5f2ea),
    );
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) => Localized(
        languageCode: 'en',
        child: MaterialApp(
          title: 'UsizoAI',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: colorScheme,
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xfff5f2ea),
            fontFamily: 'sans',
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xfff5f2ea),
              foregroundColor: forest,
              elevation: 0,
              centerTitle: false,
            ),
            cardTheme: CardThemeData(
              color: Colors.white,
              elevation: 0,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: Color(0x14153f36)),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(color: Color(0x24153f36)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(color: Color(0x24153f36)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(color: forest, width: 1.5),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(18),
            ),
            navigationBarTheme: NavigationBarThemeData(
              backgroundColor: const Color(0xff153f36),
              indicatorColor: const Color(0xffd7ed71),
              labelTextStyle: WidgetStateProperty.resolveWith(
                (states) => TextStyle(
                  color: states.contains(WidgetState.selected)
                      ? const Color(0xff153f36)
                      : Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
              iconTheme: WidgetStateProperty.resolveWith(
                (states) => IconThemeData(
                  color: states.contains(WidgetState.selected)
                      ? const Color(0xff153f36)
                      : Colors.white,
                ),
              ),
            ),
          ),
          home: _TourGate(
            tourComplete: tourComplete,
            accountReady: accountReady,
            store: store,
            remedies: remedies,
            checker: checker,
          ),
        ),
      ),
    );
  }
}

class _TourGate extends StatefulWidget {
  const _TourGate({
    required this.tourComplete,
    required this.accountReady,
    required this.store,
    required this.remedies,
    required this.checker,
  });

  final bool tourComplete;
  final bool accountReady;
  final AppStore store;
  final List<Remedy> remedies;
  final SymptomChecker checker;

  @override
  State<_TourGate> createState() => _TourGateState();
}

class _TourGateState extends State<_TourGate> {
  late var _complete = widget.tourComplete;

  @override
  Widget build(BuildContext context) {
    if (!_complete) {
      return AppTourScreen(
        onComplete: () => setState(() => _complete = true),
      );
    }
    return _AccountGate(
      accountReady: widget.accountReady,
      store: widget.store,
      remedies: widget.remedies,
      checker: widget.checker,
    );
  }
}

class _AccountGate extends StatefulWidget {
  const _AccountGate({
    required this.accountReady,
    required this.store,
    required this.remedies,
    required this.checker,
  });

  final bool accountReady;
  final AppStore store;
  final List<Remedy> remedies;
  final SymptomChecker checker;

  @override
  State<_AccountGate> createState() => _AccountGateState();
}

class _AccountGateState extends State<_AccountGate> {
  late var _ready = widget.accountReady;

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return AccountSetupScreen(
        api: widget.store.backendApi,
        onComplete: () {
          unawaited(widget.store.load());
          setState(() => _ready = true);
        },
      );
    }
    return HomeScreen(
      store: widget.store,
      remedies: widget.remedies,
      checker: widget.checker,
    );
  }
}
