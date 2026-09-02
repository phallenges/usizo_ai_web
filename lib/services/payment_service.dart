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

/// Validates activation tokens offline.
///
/// Token format: USIZO-XXXXXXXX (8 hex chars after prefix)
/// Validation: checksum is last 2 chars derived from the first 6.
class TokenValidator {
  static const _prefix = 'USIZO-';
  static const _secret = 'USIZOAI2026';

  /// Check if a token is valid.
  static bool isValid(String token) {
    final clean = token.trim().toUpperCase();
    if (!clean.startsWith(_prefix)) return false;

    final body = clean.substring(_prefix.length);
    if (body.length != 8) return false;

    final data = body.substring(0, 6);
    final check = body.substring(6, 8);

    // Simple checksum: sum of char codes * secret, modulo 256, hex encoded
    var hash = 0;
    for (int i = 0; i < data.length; i++) {
      hash = ((hash << 5) + hash + data.codeUnitAt(i)) & 0xFF;
    }
    for (int i = 0; i < _secret.length; i++) {
      hash = ((hash << 3) + hash + _secret.codeUnitAt(i)) & 0xFF;
    }

    final expected = hash.toRadixString(16).toUpperCase().padLeft(2, '0');
    return check == expected;
  }

  /// Generate a valid token (for admin use).
  static String generate(String userId) {
    // Take first 6 chars of a clean identifier
    final data = userId
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .toUpperCase()
        .padRight(6, 'X')
        .substring(0, 6);

    var hash = 0;
    for (int i = 0; i < data.length; i++) {
      hash = ((hash << 5) + hash + data.codeUnitAt(i)) & 0xFF;
    }
    for (int i = 0; i < _secret.length; i++) {
      hash = ((hash << 3) + hash + _secret.codeUnitAt(i)) & 0xFF;
    }

    final check = hash.toRadixString(16).toUpperCase().padLeft(2, '0');
    return '$_prefix$data$check';
  }
}
