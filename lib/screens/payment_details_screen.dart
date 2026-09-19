import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_store.dart';
import '../services/payment_service.dart';

/// Screen that shows EcoCash payment details.
///
/// The user sends money manually. There is no "I've paid" button.
/// They receive an activation token from the admin after payment.
class PaymentDetailsScreen extends StatefulWidget {
  const PaymentDetailsScreen({
    required this.instruction,
    required this.store,
    super.key,
  });

  final PaymentInstruction instruction;
  final AppStore store;

  @override
  State<PaymentDetailsScreen> createState() => _PaymentDetailsScreenState();
}

class _PaymentDetailsScreenState extends State<PaymentDetailsScreen> {
  final referenceController = TextEditingController();
  final messageController = TextEditingController();
  bool submitting = false;

  @override
  void dispose() {
    referenceController.dispose();
    messageController.dispose();
    super.dispose();
  }

  Future<void> _submitPayment() async {
    final reference = referenceController.text.trim();
    final message = messageController.text.trim();
    if (reference.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the EcoCash reference and confirmation message.')),
      );
      return;
    }
    setState(() => submitting = true);
    final sent = await widget.store.backendApi.submitPlusPayment(
      merchantReference: reference,
      confirmationMessage: message,
    );
    if (!mounted) return;
    setState(() => submitting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(sent
            ? 'Payment confirmation sent. We will verify it and send your token.'
            : 'Could not send confirmation. Please try again.'),
      ),
    );
    if (sent) Navigator.pop(context);
  }

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
                    widget.instruction.amountLabel,
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.instruction.description,
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
                widget.instruction.ecocashNumber,
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
                    ClipboardData(text: widget.instruction.ecocashNumber),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Number copied')),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 32),

          const Text(
            'After paying, send your EcoCash confirmation',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: referenceController,
            decoration: const InputDecoration(
              labelText: 'EcoCash transaction reference',
              hintText: 'Example: 1234567890',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: messageController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Confirmation message',
              hintText: 'Paste the message EcoCash sent you',
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: submitting ? null : _submitPayment,
            icon: submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined),
            label: Text(submitting ? 'Sending...' : 'Send confirmation for review'),
          ),
          const SizedBox(height: 16),

          // ── Disclaimer ────────────────────────────────────────────
          Text(
            'Your token will be sent after we verify the payment. Keep this confirmation '
            'message until your Plus access is activated.',
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
