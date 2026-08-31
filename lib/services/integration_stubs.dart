import 'package:flutter/material.dart';

import '../models/remedy.dart';
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

abstract interface class PaymentGateway {
  Future<PaymentResult> subscribePremium({
    required String userEmail,
    required String userName,
    required BuildContext context,
  });

  Future<PaymentResult> checkoutCart({
    required String userEmail,
    required String userName,
    required List<Remedy> items,
    required BuildContext context,
  });
}

class ProductionPaymentGateway implements PaymentGateway {
  final PaymentService _paymentService;

  ProductionPaymentGateway({
    PaymentService? paymentService,
  }) : _paymentService = paymentService ?? PaymentService(isTestMode: true);

  @override
  Future<PaymentResult> subscribePremium({
    required String userEmail,
    required String userName,
    required BuildContext context,
  }) async {
    return await _paymentService.processPremiumSubscription(
      context: context,
      userEmail: userEmail,
      userName: userName,
    );
  }

  @override
  Future<PaymentResult> checkoutCart({
    required String userEmail,
    required String userName,
    required List<Remedy> items,
    required BuildContext context,
  }) async {
    return await _paymentService.processOrder(
      context: context,
      userEmail: userEmail,
      userName: userName,
      items: items,
    );
  }
}

