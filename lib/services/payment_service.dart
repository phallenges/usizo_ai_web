import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutterwave_standard/flutterwave.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../models/remedy.dart';

/// Production payment service using Flutterwave
/// Handles both premium subscriptions and marketplace orders
class PaymentService {
  final bool isTestMode;

  PaymentService({this.isTestMode = true});

  String get _publicKey => dotenv.env['FLUTTERWAVE_PUBLIC_KEY'] ?? '';
  String get _secretKey => dotenv.env['FLUTTERWAVE_SECRET_KEY'] ?? '';

  /// Process premium subscription payment ($1.50)
  Future<PaymentResult> processPremiumSubscription({
    required BuildContext context,
    required String userEmail,
    required String userName,
  }) async {
    try {
      final transactionRef = _generateTransactionRef();

      final flutterwave = Flutterwave(
        publicKey: _publicKey,
        currency: 'USD',
        redirectUrl: '',
        txRef: transactionRef,
        amount: '1.50',
        customer: Customer(
          name: userName.isNotEmpty ? userName : 'User',
          phoneNumber: '+263712000000',
          email: userEmail.isNotEmpty ? userEmail : 'user@usizo.app',
        ),
        paymentOptions: 'ussd, card, bank transfer',
        customization: Customization(
          title: 'UsizoAI Plus',
          description: 'Unlimited health checks for premium users',
        ),
        isTestMode: isTestMode,
      );

      final response = await flutterwave.charge(context);

      if (response.success == true) {
        final verified = await _verifyPayment(
          transactionRef: transactionRef,
          amount: 1.50,
          userEmail: userEmail,
        );
        if (verified) {
          return PaymentResult.success(
            transactionRef: transactionRef,
            amount: 1.50,
          );
        }
      }

      return PaymentResult.failed(
        transactionRef: transactionRef,
        reason: 'Payment cancelled or failed',
      );
    } catch (e) {
      return PaymentResult.failed(
        transactionRef: '',
        reason: 'Payment error: $e',
      );
    }
  }

  /// Process marketplace order (bundle of remedies)
  Future<PaymentResult> processOrder({
    required BuildContext context,
    required String userEmail,
    required String userName,
    required List<Remedy> items,
  }) async {
    try {
      if (items.isEmpty) {
        return PaymentResult.failed(
          transactionRef: '',
          reason: 'Cart is empty',
        );
      }

      final totalCents = items.fold(0, (sum, r) => sum + r.priceCents);
      final totalUsd = (totalCents / 100).toStringAsFixed(2);
      final transactionRef = _generateTransactionRef();

      final flutterwave = Flutterwave(
        publicKey: _publicKey,
        currency: 'USD',
        redirectUrl: '',
        txRef: transactionRef,
        amount: totalUsd,
        customer: Customer(
          name: userName.isNotEmpty ? userName : 'Customer',
          phoneNumber: '+263712000000',
          email: userEmail.isNotEmpty ? userEmail : 'customer@usizo.app',
        ),
        paymentOptions: 'ussd, card, bank transfer',
        customization: Customization(
          title: 'UsizoAI Wellness Store',
          description:
              '${items.length} item${items.length > 1 ? 's' : ''} - USD $totalUsd',
        ),
        isTestMode: isTestMode,
      );

      final response = await flutterwave.charge(context);

      if (response.success == true) {
        final verified = await _verifyPayment(
          transactionRef: transactionRef,
          amount: double.parse(totalUsd),
          userEmail: userEmail,
        );
        if (verified) {
          return PaymentResult.success(
            transactionRef: transactionRef,
            amount: double.parse(totalUsd),
          );
        }
      }

      return PaymentResult.failed(
        transactionRef: transactionRef,
        reason: 'Payment cancelled or failed',
      );
    } catch (e) {
      return PaymentResult.failed(
        transactionRef: '',
        reason: 'Order payment error: $e',
      );
    }
  }

  /// Verify payment with Flutterwave backend
  /// Ensures payment was actually processed before granting access
  Future<bool> _verifyPayment({
    required String transactionRef,
    required double amount,
    required String userEmail,
  }) async {
    try {
      final url = Uri.parse(
        'https://api.flutterwave.com/v3/transactions/verify_by_reference?reference=$transactionRef',
      );

      final response = await http
          .get(
            url,
            headers: {
              'Authorization': 'Bearer $_secretKey',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final nestedData = data['data'] as Map<String, dynamic>?;

        if (data['status'] == 'success' &&
            nestedData != null &&
            nestedData['status'] == 'successful' &&
            double.parse(nestedData['amount'].toString()) >= amount) {
          return true;
        }
      }

      return false;
    } catch (_) {
      // Network error or timeout - payment status unknown
      // In production, implement retry logic with exponential backoff
      return false;
    }
  }

  /// Check payment status (for offline retry logic)
  Future<PaymentStatus> checkPaymentStatus(String transactionRef) async {
    if (transactionRef.isEmpty) return PaymentStatus.unknown;

    try {
      final url = Uri.parse(
        'https://api.flutterwave.com/v3/transactions/verify_by_reference?reference=$transactionRef',
      );

      final response = await http
          .get(
            url,
            headers: {'Authorization': 'Bearer $_secretKey'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final nestedData = data['data'] as Map<String, dynamic>?;
        final status = nestedData?['status'] as String? ?? 'unknown';

        switch (status) {
          case 'successful':
            return PaymentStatus.completed;
          case 'pending':
            return PaymentStatus.pending;
          case 'failed':
            return PaymentStatus.failed;
          default:
            return PaymentStatus.unknown;
        }
      }

      return PaymentStatus.unknown;
    } catch (_) {
      return PaymentStatus.unknown;
    }
  }

  /// Generate unique transaction reference
  String _generateTransactionRef() {
    final uuid = const Uuid().v4().replaceAll('-', '').substring(0, 12);
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return 'usizo_${timestamp}_$uuid';
  }

  /// Get test credentials for sandbox mode
  static Map<String, String> getTestCredentials() {
    return {
      'card': '4242424242424242',
      'cvv': '123',
      'expiry': '12/25',
      'pin': '1234',
      'otp': '123456',
      'phone': '+254712345678',
    };
  }
}

/// Represents the result of a payment operation
class PaymentResult {
  final bool isSuccess;
  final String transactionRef;
  final double amount;
  final String? errorReason;

  PaymentResult({
    required this.isSuccess,
    required this.transactionRef,
    required this.amount,
    this.errorReason,
  });

  factory PaymentResult.success({
    required String transactionRef,
    required double amount,
  }) {
    return PaymentResult(
      isSuccess: true,
      transactionRef: transactionRef,
      amount: amount,
    );
  }

  factory PaymentResult.failed({
    required String transactionRef,
    required String reason,
  }) {
    return PaymentResult(
      isSuccess: false,
      transactionRef: transactionRef,
      amount: 0,
      errorReason: reason,
    );
  }

  @override
  String toString() =>
      'PaymentResult(success: $isSuccess, ref: $transactionRef, amount: $amount${errorReason != null ? ', error: $errorReason' : ''})';
}

enum PaymentStatus {
  completed,
  pending,
  failed,
  unknown,
}
