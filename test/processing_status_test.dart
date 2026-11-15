import 'package:flutter_test/flutter_test.dart';
import 'package:printingshop/services/display_text.dart';

void main() {
  test('Processing counters include approved and legacy production statuses', () {
    const statuses = ['Order Submitted', 'For Approval', 'Approved', 'Printing',
      'Preparing', 'Processing', 'Ready for Pickup', 'Completed', 'Cancelled', 'Rejected'];
    expect(statuses.where(isProcessingOrderStatus).length, 4);
    expect(isProcessingOrderStatus('For Approval'), isFalse);
    expect(isProcessingOrderStatus('Cancelled'), isFalse);
  });

  test('Production labels are Processing in existing and new order views', () {
    for (final status in ['Printing', 'Preparing', 'Processing']) {
      expect(orderStatusLabel(status), 'Processing');
    }
    expect(orderStatusLabel('Approved'), 'Approved');
    expect(orderStatusLabel('Ready for Pickup'), 'Ready for Pickup');
  });
}
