import 'package:flutter/material.dart';

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
              ? 'Opening your emergency dialer…'
              : 'Dial 112 (South Africa) or your local emergency number now.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Urgent help')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.emergency, size: 72, color: Colors.red),
            const SizedBox(height: 18),
            Text(
              'Please get help now',
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
              label: const Text('Call emergency services'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                final opened =
                    await const EmergencyService().findNearestClinic();
                if (!context.mounted || opened) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Open Google Maps to find a clinic nearby.'),
                  ),
                );
              },
              icon: const Icon(Icons.location_on_outlined),
              label: const Text('Find nearest clinic'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Return to checker'),
            ),
            const Spacer(),
            const Text(
              'If you are with someone who is unwell, stay with them and follow the dispatcher’s instructions.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            const Text(
              'UsizoAI is not a replacement for professional medical care. Always consult a doctor for serious conditions.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
