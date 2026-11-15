import 'package:flutter_test/flutter_test.dart';
import 'package:printingshop/services/order_workflow.dart';

void main() {
  test(
      'cancelled and rejected orders contribute zero to all revenue components',
      () {
    for (final status in [
      'Cancelled',
      ' CANCELED by customer ',
      'Rejected: hahhahaag'
    ]) {
      final order = <String, dynamic>{
        'status': status,
        'source': 'POS',
        'total': 4.5e15,
        'productTotal': 4e15,
        'serviceTotal': 5e14
      };
      expect(analyticsOrderAmount(order), 0);
      expect(analyticsOrderAmount(order, 'productTotal'), 0);
      expect(analyticsOrderAmount(order, 'serviceTotal'), 0);
    }
  });

  test('active amounts keep zero totals and accept legacy currency text', () {
    expect(analyticsOrderAmount({'status': 'Completed', 'total': '₱1,200.50'}),
        1200.5);
    expect(analyticsOrderAmount({'total': 0, 'price': 99}), 0);
    expect(
        analyticsOrderAmount({'total': null, 'price': null, 'amount': 50}), 50);
    for (final total in [double.nan, double.infinity, -10, 'bad']) {
      expect(analyticsOrderAmount({'total': total}), 0);
    }
    expect(
        analyticsOrderAmount(
            {'source': 'POS', 'productTotal': 125}, 'productTotal'),
        125);
  });
}
