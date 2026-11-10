import 'loyalty_api.dart';

bool validOrderTransition(String current, String target) {
  if (current == 'Cancelled') return false;
  if (target.startsWith('Rejected'))
    return current != 'Completed' && !current.startsWith('Rejected');
  return (const {
            'Order Submitted': ['Approved'],
            'For Approval': ['Approved'],
            'Approved': ['Printing', 'Preparing'],
            'Printing': ['Ready for Pickup'],
            'Preparing': ['Ready for Pickup'],
            'Ready for Pickup': ['Completed'],
          }[current] ??
          [])
      .contains(target);
}

List<Map<String, dynamic>> inventoryItems(Map<String, dynamic> order) {
  final lines = order['items'] as List? ?? [];
  if (lines.isNotEmpty)
    return lines.map((v) {
      final line = Map<String, dynamic>.from(v as Map);
      return {
        ...line,
        'id': line['productId'] ?? line['id'],
        'qty': line['qty'] ?? line['quantity'] ?? 1
      };
    }).toList();
  final service = (order['service'] ?? '').toString();
  if (!service.toLowerCase().startsWith('in-store:')) return [];
  return RegExp(r'([^,]+?)\s*\((\d+)x\)')
      .allMatches(service.split(':').skip(1).join(':'))
      .map((m) =>
          <String, dynamic>{'name': m[1]!.trim(), 'qty': int.parse(m[2]!)})
      .toList();
}

Map<String, int> inventoryPlan(
    Map<String, dynamic> order, Map<String, Map<String, dynamic>> products,
    {bool restore = false}) {
  final quantities = <String, int>{};
  for (final item in inventoryItems(order)) {
    final id = (item['id'] ?? '').toString();
    final name = (item['name'] ?? '').toString().trim().toLowerCase();
    final matches = products.entries
        .where((p) => id.isNotEmpty
            ? p.key == id
            : (p.value['name'] ?? '').toString().trim().toLowerCase() == name)
        .toList();
    if (matches.length != 1)
      throw StateError('Product not found or ambiguous: ${item['name'] ?? id}');
    final match = matches.single;
    if (match.value['archived'] == true && !restore)
      throw StateError('Product is archived: $name');
    final qty = int.tryParse('${item['qty']}') ?? 0;
    if (qty <= 0) throw StateError('Quantity must be positive.');
    quantities[match.key] = (quantities[match.key] ?? 0) + qty;
  }
  return quantities.map((id, qty) {
    final stock = int.tryParse('${products[id]!['stock'] ?? 0}') ?? 0;
    if (!restore && stock < qty)
      throw StateError('Insufficient stock for ${products[id]!['name']}');
    return MapEntry(id, restore ? stock + qty : stock - qty);
  });
}

Future<void> updateOrderWorkflow(String id, String target,
    {String? reason, bool paymentConfirmed = false}) async {
  await LoyaltyApi.call('/api/orders/${Uri.encodeComponent(id)}/status', method: 'POST', data: {
    'status': target, 'reason': reason ?? '', 'paymentConfirmed': paymentConfirmed,
  });
}
