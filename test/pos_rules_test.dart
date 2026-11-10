import 'package:flutter_test/flutter_test.dart';
import 'package:printingshop/services/pos_rules.dart';

void main() {
  final catalog = <String, Map<String, dynamic>>{
    'product/p1': {'name': 'Notebook', 'price': 19, 'stock': 5},
    'service/s1': {'name': 'Printing', 'basePrice': 3},
  };
  Map<String, dynamic> payload() => {
        'buyerName': 'Maria Santos',
        'items': [
          {'kind': 'product', 'id': 'p1', 'qty': 2, 'unitPrice': 19},
        ],
        'expectedTotal': 38,
        'cashReceived': 100,
        'payment': 'Cash'
      };
  test('cashier buyer name, cent rounding and cash change match the website',
      () {
    final sale = validatePosSale(payload(), catalog);
    expect(sale['buyerName'], 'Maria Santos');
    expect(sale['total'], 38);
    expect(sale['change'], 62);
    expect(posCents(1.005), 101);
    expect(posCents(2.675), 268);
    expect(
        validatePosSale({...payload(), 'buyerName': ''}, catalog)['buyerName'],
        'Walk-in Customer');
  });
  test('mixed service quote keeps inventory and service totals separate', () {
    final request = payload();
    (request['items'] as List).add({
      'kind': 'service',
      'id': 's1',
      'qty': 10,
      'unitPrice': 4,
      'note': 'A4 color'
    });
    request['expectedTotal'] = 78;
    final sale = validatePosSale(request, catalog);
    expect(sale['productTotal'], 38);
    expect(sale['serviceTotal'], 40);
    expect(sale['change'], 22);
  });
  test('stock, prices, quantity, buyer and payment limits are validated', () {
    for (final change in [
      {'cashReceived': 1},
      {'expectedTotal': 1},
      {'buyerName': 'a' * 101},
      {'items': []},
      {
        'items': [null]
      },
      {'payment': 'PayMaya'},
      for (final qty in [0, -1, 1.5, true, '9' * 100, 100001])
        {
          'items': [
            {'kind': 'product', 'id': 'p1', 'qty': qty, 'unitPrice': 19}
          ]
        },
      {
        'items': [
          {'kind': 'product', 'id': 'p1', 'qty': 6, 'unitPrice': 19}
        ],
        'expectedTotal': 114
      },
      {
        'items': [
          {'kind': 'product', 'id': 'p1', 'qty': 2, 'unitPrice': 1}
        ]
      },
    ]) {
      expect(() => validatePosSale({...payload(), ...change}, catalog),
          throwsFormatException);
    }
  });
  test('GCash sale requires reference and explicit payment confirmation', () {
    final request = {
      ...payload(),
      'payment': 'GCash',
      'gcashRef': '1234567890123',
      'paymentConfirmed': true
    };
    expect(validatePosSale(request, catalog)['change'], 0);
    expect(
        () => validatePosSale({...request, 'paymentConfirmed': false}, catalog),
        throwsFormatException);
    expect(() => validatePosSale({...request, 'gcashRef': 'abc'}, catalog),
        throwsFormatException);
  });
}
