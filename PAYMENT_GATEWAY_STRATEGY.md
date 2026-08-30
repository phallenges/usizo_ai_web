# Payment Gateway Strategy for UsizoAI

## Context
- **Target Market:** Zimbabwe (remote areas with unreliable connectivity)
- **Transaction Size:** $1.50 USD (premium subscription)
- **Model:** Freemium (3 free checks) → Premium (unlimited)
- **Infrastructure:** Zero-cost, offline-first app

---

## 🏆 RECOMMENDED: Flutterwave + M-Pesa Hybrid

### Why Flutterwave?
✅ **Built for Africa** - Understands local payment ecosystems  
✅ **Multi-currency** - ZWL (Zimbabwe Dollar) or USD support  
✅ **M-Pesa Integration** - Works in Zimbabwe via regional carriers  
✅ **Low fees** - 1.4% + $0.20 (cheaper than Stripe for micro-transactions)  
✅ **Flutter SDK** - Native Flutter package available  
✅ **Fallback options** - Card, Mobile Money, Bank Transfer  
✅ **Offline support** - Queue failed transactions for retry  

### Cost Analysis ($1.50 transaction)
- **Flutterwave M-Pesa:** $1.50 × 1.4% + $0.20 = ~$0.42 fee (28% of sale)
- **Better for volume:** If users upgrade, fees decrease
- **No setup cost:** Free developer account

---

## Alternative 1: Stripe (Global Backup)

### Why Stripe?
✅ **Global standard** - Best if users outside Zimbabwe  
✅ **Reliable** - Enterprise-grade infrastructure  
✅ **Good Flutter support** - Well-documented  
❌ **Higher fees** - 2.9% + $0.30 (much worse for $1.50)  
❌ **Limited mobile money** - Doesn't support M-Pesa directly  

### When to use:
- Users in US, EU, or Western markets
- Supplement Flutterwave for global reach

---

## Alternative 2: PayPal

### Why PayPal?
✅ **Widely recognized** - Many users have accounts  
✅ **Simple integration** - Flutter plugin available  
✅ **Handles disputes** - Good buyer protection  
❌ **Expensive for micro** - 3.49% + $0.49 (33% fee on $1.50!)  
❌ **Account holds** - PayPal can freeze funds  

---

## Alternative 3: Direct M-Pesa (No Middleman)

### Why Direct?
✅ **Lowest fees** - Control costs directly  
✅ **Local first** - Familiar to Zimbabwe users  
❌ **Complex** - Requires M-Pesa Business Account  
❌ **Regional only** - Won't help international users  
❌ **PCI compliance** - More security responsibility  

### Cost:
- $0-50/month for M-Pesa Business API
- M-Pesa charges ~2.5% per transaction
- **Total on $1.50:** ~$0.04-0.04 (3%)

---

## ✅ IMPLEMENTATION PLAN (Recommended)

### Phase 1: Flutterwave (Weeks 1-2)
1. **Sign up** → https://dashboard.flutterwave.com
2. **Get API Keys** → Public & Secret keys
3. **Add dependency:**
   ```yaml
   dependencies:
     flutterwave_flutter: ^1.0.0
   ```
4. **Implement payment widget:**
   - Use Flutterwave's `ChargeCard` for payment
   - Setup M-Pesa as primary method
   - Card as fallback

### Phase 2: Webhook Verification (Week 3)
- Setup webhook to verify payment success
- Update `premium` flag in `AppStore` on successful payment
- Handle failed/pending transactions

### Phase 3: Testing (Week 4)
- Test in sandbox environment
- Use Flutterwave test cards
- Go live

---

## Code Structure

### Add to pubspec.yaml
```yaml
dependencies:
  flutterwave_flutter: ^1.0.0
  http: ^1.1.0
```

### Create Payment Service
```dart
// lib/services/flutterwave_payment.dart

class FlutterwavePaymentService {
  static const String publicKey = 'YOUR_PUBLIC_KEY';
  static const String secretKey = 'YOUR_SECRET_KEY';
  
  Future<bool> processPremiumSubscription(String userId) async {
    // Generate unique reference
    final ref = 'usizo_${userId}_${DateTime.now().millisecondsSinceEpoch}';
    
    // Charge customer
    final response = await FlutterwaveFlutterPay(
      context: context,
      publicKey: publicKey,
      currency: "USD",
      rxRef: ref,
      amount: 1.50,
      paymentOptions: "ussd, card, barter, bank transfer, wallet",
      customization: PaymentCustomization(
        title: "UsizoAI Plus",
        description: "Unlimited health checks",
        logo: "https://your-domain.com/logo.png",
      ),
      isTestMode: false,
      onSuccess: (ChargeResponse response) {
        _handlePaymentSuccess(response);
      },
      onError: (String error) {
        _handlePaymentError(error);
      },
      onWillClose: () {},
    ).charge();
    
    return response.success ?? false;
  }
  
  void _handlePaymentSuccess(ChargeResponse response) {
    // Update AppStore.setPremium(true)
    // Log to backend
  }
}
```

### Update Integration Stubs
```dart
// lib/services/integration_stubs.dart

class ProductionPaymentGateway implements PaymentGateway {
  final FlutterwavePaymentService _flutterwave;
  
  const ProductionPaymentGateway(this._flutterwave);

  @override
  Future<bool> checkout(List<Remedy> remedies) async {
    return await _flutterwave.processPremiumSubscription(userId);
  }
}
```

---

## Security Checklist

- [ ] **Never expose Secret Key** in app code
- [ ] **Use environment variables** for API keys
- [ ] **Verify webhook signatures** on backend
- [ ] **Encrypt stored payment data** (if any)
- [ ] **Use HTTPS only** for API calls
- [ ] **Implement rate limiting** on payment endpoints
- [ ] **Log all transactions** for audit trail
- [ ] **Handle PCI compliance** (ideally via Flutterwave)

---

## Deployment Checklist

- [ ] Get Flutterwave Business Account (requires ID verification)
- [ ] Set up M-Pesa merchant account (through Flutterwave)
- [ ] Create webhook endpoint on backend to verify payments
- [ ] Test in sandbox mode first
- [ ] Switch to production API keys when ready
- [ ] Monitor transactions in Flutterwave dashboard
- [ ] Setup payment reconciliation process

---

## Alternatives Summary

| Gateway | Fee (on $1.50) | M-Pesa | Multi-currency | Flutter | Africa-First |
|---------|---|---|---|---|---|
| **Flutterwave** ⭐ | $0.42 | ✅ | ✅ | ✅ | ✅ |
| Stripe | $0.74 | ❌ | ✅ | ✅ | ❌ |
| PayPal | $0.51 | ❌ | ✅ | ✅ | ❌ |
| Direct M-Pesa | $0.04 | ✅ | ❌ | 🟡 | ✅ |

---

## Gotchas for Zimbabwe/Remote Areas

1. **Connectivity issues** → Queue payments offline, retry on reconnect
2. **Currency volatility** → Display ZWL prices alongside USD
3. **Low data** → Optimize API calls, cache validation responses
4. **Phone verification** → M-Pesa may require phone number validation
5. **Failed payments** → Show user-friendly retry logic

---

## Resources

- **Flutterwave Docs:** https://developer.flutterwave.com/docs
- **Flutter Plugin:** https://pub.dev/packages/flutterwave_flutter
- **M-Pesa Integration:** https://developer.flutterwave.com/docs/getting-started/transfer-flows/collect-money#using-mpesa
- **Test Credentials:** https://developer.flutterwave.com/docs/getting-started/setup#using-the-test-keys

---

## Next Steps

1. **Decide:** Do you want Flutterwave recommended approach?
2. **Signup:** Create account at flutterwave.com
3. **Test:** Get API keys, implement in sandbox
4. **Integrate:** Add payment flow to `marketplace_screen.dart`
5. **Verify:** Setup webhook to confirm payments on backend

Ready to implement? I can create the payment service code for you.
