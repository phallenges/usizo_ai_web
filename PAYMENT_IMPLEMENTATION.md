# Flutterwave Payment Integration - Step-by-Step

## Quick Summary
**Best for Zimbabwe:** Flutterwave + M-Pesa  
**Cost:** $0.42 per $1.50 transaction (28% fee)  
**Setup time:** ~2-3 hours  
**Complexity:** Moderate

---

## Step 1: Setup Flutterwave Account

### 1.1 Create Account
```
1. Go to https://dashboard.flutterwave.com/signup
2. Register with email + password
3. Verify email
4. Complete KYC (Know Your Customer):
   - Business details
   - Identification
   - Bank account (for payouts)
```

### 1.2 Get API Keys
```
Dashboard → Settings → API → Copy:
- LIVE PUBLIC KEY (starts with "pk_live_")
- LIVE SECRET KEY (starts with "sk_live_")
- TEST PUBLIC KEY
- TEST SECRET KEY
```

### 1.3 Enable M-Pesa (optional but recommended)
```
Settings → Payment Methods → Enable M-Pesa
You may need to provide:
- M-Pesa Merchant Code
- M-Pesa API credentials
```

---

## Step 2: Add Dependencies

### 2.1 Update pubspec.yaml
```yaml
dependencies:
  flutter:
    sdk: flutter
  shared_preferences: ^2.3.2
  url_launcher: ^6.3.1
  onnx_runtime_flutter: ^1.19.0
  vector_math: ^2.1.4
  flutterwave_flutter: ^1.0.0          # ← ADD THIS
  http: ^1.1.0                          # ← ADD THIS
  uuid: ^4.0.0                          # ← ADD THIS (for transaction IDs)
```

### 2.2 Run pub get
```bash
cd C:\src\usizo_ai_web
flutter pub get
```

---

## Step 3: Create Payment Service

### 3.1 Create new file: `lib/services/payment_service.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutterwave_flutter/flutterwave.dart';
import 'package:flutterwave_flutter/models/requests/customer.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/remedy.dart';

/// Production payment service using Flutterwave
class PaymentService {
  // Replace with your actual keys from Flutterwave dashboard
  static const String publicKey = 'pk_live_YOUR_PUBLIC_KEY_HERE';
  static const String secretKey = 'sk_live_YOUR_SECRET_KEY_HERE';
  
  /// Process premium subscription payment
  Future<bool> processPremiumSubscription({
    required BuildContext context,
    required String userEmail,
    required String userName,
  }) async {
    final transactionRef = _generateTransactionRef();
    
    try {
      final result = await Flutterwave.forUIPayment(
        context: context,
        publicKey: publicKey,
        encryptionKey: "FLWSECK_TEST0fbe42f14e84", // Get from Flutterwave dashboard
        txRef: transactionRef,
        amount: "1.50",
        currency: "USD",
        customer: Customer(
          name: userName,
          phoneNumber: "+263-",  // Zimbabwe country code
          email: userEmail,
        ),
        paymentOptions: "ussd, card, barter, bank transfer, wallet",
        customization: Customization(
          title: "UsizoAI Plus",
          logo: "https://platform.slack-edge.com/img/default_application_icon.png",
          description: "Unlimited health checks for premium users",
        ),
        isTestMode: false, // Set to true for testing
        onComplete: (response) async {
          if (response?.status == "successful") {
            // Verify payment on backend
            final verified = await _verifyPayment(
              transactionRef: transactionRef,
              amount: 1.50,
              userEmail: userEmail,
            );
            return verified;
          }
          return false;
        },
      );
      
      return result ?? false;
    } catch (e) {
      print('Payment error: $e');
      return false;
    }
  }

  /// Process marketplace order (bundle of remedies)
  Future<bool> processOrder({
    required BuildContext context,
    required String userEmail,
    required String userName,
    required List<Remedy> items,
  }) async {
    final total = (items.fold(0, (sum, r) => sum + r.priceCents) / 100)
        .toStringAsFixed(2);
    final transactionRef = _generateTransactionRef();
    
    try {
      final result = await Flutterwave.forUIPayment(
        context: context,
        publicKey: publicKey,
        encryptionKey: "FLWSECK_TEST0fbe42f14e84",
        txRef: transactionRef,
        amount: total,
        currency: "USD",
        customer: Customer(
          name: userName,
          phoneNumber: "+263-",
          email: userEmail,
        ),
        paymentOptions: "ussd, card, barter, bank transfer, wallet",
        customization: Customization(
          title: "UsizoAI Wellness Store",
          logo: "https://platform.slack-edge.com/img/default_application_icon.png",
          description: "${items.length} item${items.length > 1 ? 's' : ''} - $total USD",
        ),
        isTestMode: false,
        onComplete: (response) async {
          if (response?.status == "successful") {
            final verified = await _verifyPayment(
              transactionRef: transactionRef,
              amount: double.parse(total),
              userEmail: userEmail,
            );
            return verified;
          }
          return false;
        },
      );
      
      return result ?? false;
    } catch (e) {
      print('Order payment error: $e');
      return false;
    }
  }

  /// Verify payment with Flutterwave backend
  /// This ensures the payment was actually processed
  Future<bool> _verifyPayment({
    required String transactionRef,
    required double amount,
    required String userEmail,
  }) async {
    try {
      final url = Uri.parse(
        'https://api.flutterwave.com/v3/transactions/verify_by_reference?'
        'reference=$transactionRef',
      );
      
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $secretKey',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Check if payment succeeded
        if (data['status'] == 'success' &&
            data['data']['status'] == 'successful' &&
            double.parse(data['data']['amount'].toString()) >= amount) {
          // Payment verified! Update user account
          print('✅ Payment verified for $userEmail');
          return true;
        }
      }
      
      print('❌ Payment verification failed: ${response.body}');
      return false;
    } catch (e) {
      print('Verification error: $e');
      return false;
    }
  }

  /// Generate unique transaction reference
  String _generateTransactionRef() {
    final uuid = const Uuid().v4().replaceAll('-', '').substring(0, 12);
    return 'usizo_${DateTime.now().millisecondsSinceEpoch ~/ 1000}_$uuid';
  }

  /// Check payment status (for offline retry logic)
  Future<PaymentStatus> checkPaymentStatus(String transactionRef) async {
    try {
      final url = Uri.parse(
        'https://api.flutterwave.com/v3/transactions/verify_by_reference?'
        'reference=$transactionRef',
      );
      
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $secretKey'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final status = data['data']['status'];
        
        if (status == 'successful') {
          return PaymentStatus.completed;
        } else if (status == 'pending') {
          return PaymentStatus.pending;
        } else {
          return PaymentStatus.failed;
        }
      }
      
      return PaymentStatus.unknown;
    } catch (e) {
      return PaymentStatus.unknown;
    }
  }
}

enum PaymentStatus {
  completed,
  pending,
  failed,
  unknown,
}
```

### 3.2 Update `integration_stubs.dart` to use real payment

```dart
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
  Future<bool> checkout(List<Remedy> remedies, {
    required String userEmail,
    required String userName,
    required BuildContext context,
  });
  
  Future<bool> subscribePremium({
    required String userEmail,
    required String userName,
    required BuildContext context,
  });
}

class ProductionPaymentGateway implements PaymentGateway {
  final PaymentService _paymentService = PaymentService();

  const ProductionPaymentGateway();

  @override
  Future<bool> checkout(
    List<Remedy> remedies, {
    required String userEmail,
    required String userName,
    required BuildContext context,
  }) async {
    return await _paymentService.processOrder(
      context: context,
      userEmail: userEmail,
      userName: userName,
      items: remedies,
    );
  }

  @override
  Future<bool> subscribePremium({
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
}
```

---

## Step 4: Update UI to Use Payment Service

### 4.1 Update `marketplace_screen.dart` checkout button

Find the "Place Order" button and update it:

```dart
FilledButton(
  onPressed: () async {
    Navigator.pop(context);
    
    // Show loading
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: SizedBox(
          height: 100,
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      ),
    );
    
    final gateway = ProductionPaymentGateway();
    final success = await gateway.checkout(
      widget.store.cart,
      userEmail: widget.store.profile.email,
      userName: widget.store.profile.name,
      context: context,
    );
    
    if (!mounted) return;
    Navigator.pop(context); // Close loading dialog
    
    if (success) {
      widget.store.clearCart();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Order completed! Thank you.'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Payment failed. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  },
  child: const Text('Place Order'),
),
```

### 4.2 Update `profile_screen.dart` to use payment for Plus upgrade

```dart
FilledButton(
  onPressed: () async {
    final gateway = ProductionPaymentGateway();
    final success = await gateway.subscribePremium(
      userEmail: widget.store.profile.email,
      userName: widget.store.profile.name,
      context: context,
    );
    
    if (success) {
      widget.store.setPremium(true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Welcome to UsizoAI Plus!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Payment failed. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  },
  child: const Text('Subscribe to Plus ($1.50)'),
),
```

---

## Step 5: Environment Configuration

### 5.1 Create `.env.local` (don't commit this!)

```
FLUTTERWAVE_PUBLIC_KEY=pk_live_YOUR_ACTUAL_KEY
FLUTTERWAVE_SECRET_KEY=sk_live_YOUR_ACTUAL_SECRET
```

### 5.2 Update payment_service.dart to use env

```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PaymentService {
  static String get publicKey => dotenv.env['FLUTTERWAVE_PUBLIC_KEY'] ?? '';
  static String get secretKey => dotenv.env['FLUTTERWAVE_SECRET_KEY'] ?? '';
  
  // ... rest of code
}
```

### 5.3 Add to pubspec.yaml

```yaml
dependencies:
  flutter_dotenv: ^5.1.0
```

### 5.4 Update main.dart

```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: ".env.local");
  
  // ... rest of main
}
```

---

## Step 6: Testing

### 6.1 Test Mode Setup
Change in `payment_service.dart`:
```dart
isTestMode: true,  // ← Set to true for testing
```

### 6.2 Flutterwave Test Cards
```
Card Number: 4242424242424242
CVV: 123
Expiry: 12/25
PIN: 1234
OTP: 123456
```

### 6.3 Test M-Pesa (if enabled)
```
Phone: +254712345678
OTP: 123456
```

### 6.4 Run test transactions
```bash
flutter run
# Navigate to Plus upgrade
# Click "Subscribe to Plus ($1.50)"
# Use test card above
# Should see success message
```

---

## Step 7: Security Hardening

### 7.1 Never commit API keys
```
# Add to .gitignore
.env.local
.env.production
```

### 7.2 Verify webhook signatures (backend)
```dart
String validateWebhookSignature(
  String payload,
  String signature,
  String secretKey,
) {
  // Implement HMAC-SHA256 verification
  // See: https://developer.flutterwave.com/docs/webhooks/
}
```

### 7.3 Rate limiting
```dart
class RateLimiter {
  final Map<String, List<DateTime>> _attempts = {};
  static const maxAttempts = 5;
  static const windowSeconds = 60;
  
  bool allowPayment(String userEmail) {
    final now = DateTime.now();
    final key = userEmail;
    
    _attempts[key] ??= [];
    _attempts[key]!.removeWhere(
      (t) => now.difference(t).inSeconds > windowSeconds,
    );
    
    if (_attempts[key]!.length >= maxAttempts) {
      return false;
    }
    
    _attempts[key]!.add(now);
    return true;
  }
}
```

---

## Step 8: Go Live Checklist

- [ ] Get Flutterwave Business Account approved
- [ ] Verify all bank details in Flutterwave dashboard
- [ ] Switch `isTestMode: false`
- [ ] Update API keys to LIVE keys
- [ ] Test one real transaction with small amount
- [ ] Setup payment confirmation emails
- [ ] Monitor Flutterwave dashboard for transactions
- [ ] Create refund/dispute process
- [ ] Add transaction logging to backend
- [ ] Setup payment reconciliation (daily/weekly)

---

## Troubleshooting

### Payment shows pending but not verified
```
Solutions:
1. Check Flutterwave dashboard for status
2. Try manual verification endpoint
3. Retry verification after 30 seconds
```

### M-Pesa not appearing as payment option
```
Solutions:
1. Verify M-Pesa enabled in Flutterwave settings
2. Check merchant code configured
3. Ensure user has M-Pesa enabled on their device
```

### High fee rate on transactions
```
Solutions:
1. Negotiate volume discounts with Flutterwave
2. Consider direct M-Pesa for high-volume
3. Use Stripe for card-only transactions
```

---

## Resources

- **Flutterwave Dashboard:** https://dashboard.flutterwave.com
- **API Docs:** https://developer.flutterwave.com/docs
- **Flutter Plugin:** https://pub.dev/packages/flutterwave_flutter
- **Community Support:** https://developer.flutterwave.com/docs/support

Ready to implement? Let me know if you hit any issues!
