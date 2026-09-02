import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/payment_service.dart';

/// Screen that shows EcoCash payment details.
///
/// The user sends money manually. There is no "I've paid" button.
/// They receive an activation token from the admin after payment.
class PaymentDetailsScreen extends StatelessWidget {
  const PaymentDetailsScreen({required this.instruction, super.key});

  final PaymentInstruction instruction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscribe to UsizoAI Plus'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          // ── Amount ────────────────────────────────────────────────
          Card(
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    instruction.amountLabel,
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    instruction.description,
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Steps ────────────────────────────────────────────────
          Text(
            'How to subscribe',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _Step(
            number: 1,
            text: 'Send \$1.50 via EcoCash to the number below',
          ),
          const SizedBox(height: 8),
          _Step(
            number: 2,
            text: 'You will receive an activation token',
          ),
          const SizedBox(height: 8),
          _Step(
            number: 3,
            text: 'Enter the token in the app to unlock Plus',
          ),
          const SizedBox(height: 24),

          // ── EcoCash number ───────────────────────────────────────
          Text(
            'Send payment to',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.phone_android),
              title: Text(
                instruction.ecocashNumber,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text('EcoCash — UsizoAI'),
              trailing: IconButton(
                icon: const Icon(Icons.copy),
                tooltip: 'Copy number',
                onPressed: () {
                  Clipboard.setData(
                    ClipboardData(text: instruction.ecocashNumber),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Number copied')),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 32),

          // ── Done button ──────────────────────────────────────────
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
          const SizedBox(height: 16),

          // ── Disclaimer ────────────────────────────────────────────
          Text(
            'Your activation token will be sent to you after payment is verified. '
            'This usually takes a few minutes.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: Text(
            '$number',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ),
      ],
    );
  }
}
