import 'package:flutter_test/flutter_test.dart';
import 'package:printingshop/services/notification_destination.dart';

void main() {
  test('Order notifications open orders, including older backend payloads', () {
    expect(notificationDestination({'type': 'order_status'}), 'orders');
    expect(notificationDestination({'click_url': '/customer?tab=myOrders'}),
        'orders');
    expect(notificationDestination({'type': 'new_order'}), 'orders');
    expect(notificationDestination({}), 'orders');
  });
  test('Chat payloads and legacy links open chat', () {
    expect(notificationDestination({'type': 'chat'}), 'chat');
    expect(
        notificationDestination({'conversation_id': 'conv_customer'}), 'chat');
    expect(
        notificationDestination({'click_url': '/customer?tab=chat'}), 'chat');
    expect(
        notificationDestination({'click_url': '/admin?tab=liveChat'}), 'chat');
  });
}
