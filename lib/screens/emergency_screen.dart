import 'package:flutter/material.dart';

import '../l10n/localized.dart';
import '../services/emergency_service.dart';

class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({required this.reason, super.key});

  final String reason;

  Future<void> _call(BuildContext context) async {
    final called = await const EmergencyService().callEmergencyServices();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          called
              ? context.tr('emergency.openingDialer')
              : '${context.tr('emergency.dialNow')} ${EmergencyService.emergencyNumber}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('emergency.title'))),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.emergency, size: 72, color: Colors.red),
            const SizedBox(height: 18),
            Text(
              context.tr('emergency.pleaseGetHelp'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade800,
                  ),
            ),
            const SizedBox(height: 12),
            Text(reason, textAlign: TextAlign.center),
            const SizedBox(height: 28),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
              onPressed: () => _call(context),
              icon: const Icon(Icons.phone),
              label: Text(context.tr('emergency.callServices')),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                final opened =
                    await const EmergencyService().findNearestClinic();
                if (!context.mounted || opened) return;
                ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.tr('emergency.findClinicMsg')),
                  ),
                );
              },
              icon: const Icon(Icons.location_on_outlined),
              label: Text(context.tr('emergency.findClinic')),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.tr('emergency.returnToChecker')),
            ),
            const Spacer(),
            Text(
              context.tr('emergency.withSomeone'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            Text(
              context.tr('market.disclaimer'),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
