import 'package:flutter_test/flutter_test.dart';
import 'package:printingshop/services/app_notifications.dart';
import 'package:printingshop/services/display_text.dart';
import 'package:printingshop/services/order_validation.dart';
import 'package:printingshop/services/loyalty_api.dart';

void main() {
  test('historical system labels display in English', () {
    expect(systemDisplayText('Walang napiling file'), 'No file selected');
    expect(systemDisplayText('Walang in-attach na file'), 'No file attached');
    expect(systemDisplayText('my-document.pdf'), 'my-document.pdf');
  });
  test('historical status notifications display in English', () {
    final notification = InboxNotification(
        'n1',
        {
          'title': 'Order Status: Approved',
          'message':
              'Ang iyong Printing (PRNT-123456) ay nasa status na: Approved.',
        },
        unread: true);
    expect(
        notification.message, 'Your Printing (PRNT-123456) is now Approved.');
    final chat = InboxNotification(
        'chat', {'type': 'chat', 'message': 'Salamat po'},
        unread: true);
    expect(chat.message, 'Salamat po');
  });
  test('validation and rewards errors are English', () {
    expect(loyaltyErrorMessage(const FormatException('Insufficient points.')),
        'You do not have enough available points for this reward.');
    expect(OrderValidation.validatePayment('GCash', 'bad'),
        'Enter a valid GCash reference number (8–16 digits, usually 13).');
  });
}
