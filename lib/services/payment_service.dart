import 'package:uuid/uuid.dart';

/// Payment service for premium subscriptions only.
///
/// Marketplace products are handled by contacting vendors directly.
/// Users send money via EcoCash and confirm with a reference number.
class PaymentService {
  // ── Configure your payment details here ──────────────────────────
  static const ecocashNumber = '0774605104';
  static const accountName = 'UsizoAI';
  // ─────────────────────────────────────────────────────────────────

  /// Generate a unique reference the user should include when paying.
  String generateReference() {
    final short =
        const Uuid().v4().replaceAll('-', '').substring(0, 8).toUpperCase();
    return 'USIZO-$short';
  }

  /// Create a payment instruction for a premium subscription.
  PaymentInstruction subscriptionInstruction({
    required String userName,
  }) {
    return PaymentInstruction(
      amountUsd: 1.50,
      reference: generateReference(),
      description: 'UsizoAI Plus — Unlimited health checks',
      recipientName: accountName,
      ecocashNumber: ecocashNumber,
    );
  }
}

/// A payment instruction shown to the user so they can pay manually.
class PaymentInstruction {
  final double amountUsd;
  final String reference;
  final String description;
  final String recipientName;
  final String ecocashNumber;

  const PaymentInstruction({
    required this.amountUsd,
    required this.reference,
    required this.description,
    required this.recipientName,
    required this.ecocashNumber,
  });

  String get amountLabel => '\$${amountUsd.toStringAsFixed(2)}';
}
