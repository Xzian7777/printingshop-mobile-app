import 'loyalty_api.dart';

class PaymentEligibility {
  final bool cashOnPickupAllowed;
  final bool hasOrders;

  const PaymentEligibility({
    required this.cashOnPickupAllowed,
    required this.hasOrders,
  });

  static const lockedMessage =
      'Cash on Pickup unlocks after your first payment-verified, completed order. Please use GCash for your first order.';

  static Future<PaymentEligibility> load() async {
    final account = await LoyaltyApi.call('/api/loyalty/me');
    return PaymentEligibility(
      cashOnPickupAllowed: account['cashOnPickupAllowed'] == true,
      hasOrders: account['hasOrders'] == true,
    );
  }
}
