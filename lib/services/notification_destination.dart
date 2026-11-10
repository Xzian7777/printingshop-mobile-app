/// Supports current payloads and web links sent by older backend versions.
String notificationDestination(Map<String, dynamic> data) {
  final type = (data['type'] ?? '').toString();
  final link = (data['click_url'] ?? '').toString();
  if (type == 'order_status' ||
      type == 'new_order' ||
      link.contains('myOrders')) {
    return 'orders';
  }
  if (type == 'chat' ||
      data.containsKey('conversation_id') ||
      link.contains('chat') ||
      link.contains('liveChat')) {
    return 'chat';
  }
  return 'orders';
}
