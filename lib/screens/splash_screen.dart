import 'package:flutter/material.dart';

import '../widgets/usizo_logo.dart';

/// Splash screen shown while the app loads its ML models and data.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: UsizoLogo(size: 140, showText: true),
      ),
    );
  }
}
