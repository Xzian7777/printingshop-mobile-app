import 'loyalty_api.dart';

bool canCancelOrder(Map<String, dynamic> order) =>
    order['source'] != 'POS' &&
    ['Order Submitted', 'For Approval'].contains(
        order.containsKey('status') ? order['status'] : 'Order Submitted') &&
    order['approvedAt'] == null &&
    (!order.containsKey('stockDeducted') || order['stockDeducted'] == false);

Future<void> cancelCustomerOrder(String id, String reason) async {
  await LoyaltyApi.call('/api/orders/${Uri.encodeComponent(id)}/cancel', method: 'POST', data: {'reason': reason});
}
