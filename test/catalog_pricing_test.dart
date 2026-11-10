import 'package:flutter_test/flutter_test.dart';
import 'package:printingshop/services/catalog_pricing.dart';

void main() {
  test('service price edits apply to new order totals', () {
    for (final service in [
      'businessCards',
      'flyers',
      'stickers',
      'invitations',
      'shirt',
      'mug'
    ]) {
      expect(
          catalogTotal(
              serviceId: service, basePrice: 25, quantity: 4, pages: 1),
          100);
      expect(
          catalogTotal(
              serviceId: service, basePrice: 30, quantity: 4, pages: 1),
          120);
    }
  });
  test('area, booklet and document calculations match website formulas', () {
    expect(
        catalogTotal(
            serviceId: 'tarpaulins',
            basePrice: 15,
            quantity: 2,
            pages: 1,
            width: 3,
            height: 4),
        360);
    expect(
        catalogTotal(
            serviceId: 'booklets', basePrice: 45, quantity: 10, pages: 12),
        1350);
    expect(
        catalogTotal(
            serviceId: 'standardA4', basePrice: 3, quantity: 2, pages: 10),
        60);
    expect(
        catalogTotal(serviceId: 'custom', basePrice: 5, quantity: 2, pages: 4),
        40);
    expect(
        catalogTotal(
            serviceId: 'photoCanvas',
            basePrice: 120,
            quantity: 2,
            pages: 1,
            photoPrice: 250),
        500);
  });
}
