import 'package:flutter_test/flutter_test.dart';
import 'package:printingshop/services/order_workflow.dart';

void main() {
  final products = <String, Map<String, dynamic>>{
    'p1': {'name': 'Paper', 'stock': 10},
    'p2': {'name': 'Pen', 'stock': 4},
  };
  test('approval has a distinct step before production', () {
    expect(validOrderTransition('Order Submitted', 'Approved'), isTrue);
    expect(validOrderTransition('Order Submitted', 'Printing'), isFalse);
    expect(validOrderTransition('Approved', 'Printing'), isTrue);
    expect(validOrderTransition('Printing', 'Ready for Pickup'), isTrue);
    expect(validOrderTransition('Ready for Pickup', 'Completed'), isTrue);
    expect(validOrderTransition('Completed', 'Rejected'), isFalse);
    expect(validOrderTransition('Rejected', 'Approved'), isFalse);
    expect(validOrderTransition('For Approval', 'Approved'), isTrue);
  });
  test('repeated item lines are aggregated before checking stock', () {
    final order = {
      'items': [
        {'id': 'p1', 'qty': 3},
        {'productId': 'p1', 'qty': 2},
        {'id': 'p2', 'qty': 1}
      ]
    };
    expect(inventoryPlan(order, products), {'p1': 5, 'p2': 3});
    expect(inventoryPlan(order, products, restore: true), {'p1': 15, 'p2': 5});
  });
  test('legacy store orders use exact product names and per-item quantities',
      () {
    expect(
        inventoryPlan({'service': 'In-Store: Paper (2x), Pen (1x)'}, products),
        {'p1': 8, 'p2': 3});
    expect(inventoryPlan({'service': 'Standard A4 Print'}, products), isEmpty);
    expect(() => inventoryPlan({'service': 'In-Store: Pap (2x)'}, products),
        throwsStateError);
  });
  test('unknown IDs never fall back to another product name', () {
    expect(
        () => inventoryPlan({
              'items': [
                {'id': 'missing', 'name': 'Paper', 'qty': 1}
              ]
            }, products),
        throwsStateError);
  });
  test('insufficient, invalid and archived stock is blocked', () {
    for (final qty in [0, -1, 11]) {
      expect(
          () => inventoryPlan({
                'items': [
                  {'id': 'p1', 'qty': qty}
                ]
              }, products),
          throwsStateError);
    }
    final archived = {
      'p1': {'name': 'Paper', 'stock': 10, 'archived': true}
    };
    expect(
        () => inventoryPlan({
              'items': [
                {'id': 'p1', 'qty': 1}
              ]
            }, archived),
        throwsStateError);
    expect(
        inventoryPlan({
          'items': [
            {'id': 'p1', 'qty': 1}
          ]
        }, archived, restore: true),
        {'p1': 11});
  });
}
