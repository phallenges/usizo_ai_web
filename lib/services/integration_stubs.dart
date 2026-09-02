import 'payment_service.dart';

abstract interface class AiProvider {
  Future<String?> explain(String symptoms);
}

class CredentialedAiProvider implements AiProvider {
  const CredentialedAiProvider({this.apiKey});

  final String? apiKey;

  bool get isConfigured => apiKey != null && apiKey!.trim().isNotEmpty;

  @override
  Future<String?> explain(String symptoms) async {
    if (!isConfigured) return null;
    throw UnimplementedError(
      'AI provider implementation required for production deployment. '
      'Configure an API key and implement HTTP client integration.',
    );
  }
}

/// Simple wrapper around PaymentService for premium subscriptions.
///
/// Marketplace products are handled by contacting vendors directly —
/// no automated checkout needed.
class ProductionPaymentGateway {
  final PaymentService _paymentService;

  ProductionPaymentGateway({PaymentService? paymentService})
      : _paymentService = paymentService ?? PaymentService();

  /// Generate a subscription payment instruction.
  PaymentInstruction subscribePremium({
    required String userEmail,
    required String userName,
  }) {
    return _paymentService.subscriptionInstruction(userName: userName);
  }
}
