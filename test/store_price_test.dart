import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printingshop/services/store_price.dart';
import 'package:printingshop/services/order_number_input_formatter.dart';
import 'package:printingshop/screens/product_detail_screen.dart';
import 'package:printingshop/widgets/store_product_card.dart';
import 'package:printingshop/widgets/store_checkout_sheet.dart';
import 'package:printingshop/theme/dashboard_theme.dart';

void main() {
  test('legacy invalid prices are rejected without changing valid amounts', () {
    for (final value in [
      5.6e150,
      double.infinity,
      double.nan,
      -1,
      5000000.01,
      null,
      true,
      'invalid'
    ]) {
      expect(storePrice(value), isNull);
    }
    expect(storePrice('19.00'), 19);
    expect(storePrice(0), 0);
    expect(storePrice(5000000), 5000000);
  });

  test(
      'product price input blocks exponent, oversized pastes and excess decimals',
      () {
    final formatter =
        OrderNumberInputFormatter(maximum: 5000000, allowDecimals: true);
    const initial = TextEditingValue(text: '19');
    for (final text in ['5.6e150', '9' * 100, '5000000.01', '19.999', '-1']) {
      expect(formatter.formatEditUpdate(initial, TextEditingValue(text: text)),
          initial);
    }
    expect(
        formatter
            .formatEditUpdate(initial, const TextEditingValue(text: '19.50'))
            .text,
        '19.50');
  });

  testWidgets(
      'a bad catalog price shows a readable label while the card still opens',
      (tester) async {
    var opened = false;
    await tester.pumpWidget(MaterialApp(
        theme: DashboardTheme.light,
        home: Scaffold(
            body: SizedBox(
                width: 170,
                height: 250,
                child: StoreProductCard(
                    name: 'Wagyu',
                    price: 5.6e150,
                    stock: 12,
                    image: const Icon(Icons.inventory_2_outlined),
                    onOpen: () => opened = true)))));
    expect(find.text('Price unavailable'), findsOneWidget);
    expect(find.textContaining('e+150'), findsNothing);
    await tester.tap(find.text('Wagyu'));
    expect(opened, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'invalid product details disable purchases and do not calculate a false total',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var bought = false;
    await tester.pumpWidget(MaterialApp(
        theme: DashboardTheme.light,
        home: Scaffold(
            body: ProductDetailScreen(
                productId: 'p1',
                productData: const {
                  'name': 'Wagyu',
                  'price': 5.6e150,
                  'stock': 12
                },
                onBuyNow: (_) => bought = true))));
    await tester.ensureVisible(find.text('Buy Now'));
    final buy = tester.widget<ElevatedButton>(find.ancestor(
        of: find.text('Buy Now'), matching: find.byType(ElevatedButton)));
    expect(buy.onPressed, isNull);
    expect(bought, isFalse);
    expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('productTotalPrice')))
            .data,
        '—');
    expect(tester.takeException(), isNull);
  });

  testWidgets('an invalid item already in the cart cannot be submitted',
      (tester) async {
    var submitted = false;
    await tester.pumpWidget(MaterialApp(
        theme: DashboardTheme.light,
        home: Scaffold(
            body: StoreCheckoutSheet(
                cart: const {
              'p1': 1
            },
                products: const {
              'p1': {'name': 'Wagyu', 'price': 5.6e150, 'stock': 12}
            },
                merchantSettings: Stream.value(const {'isActive': false}),
                onCartChanged: (_) {},
                onCheckout: (_, entries, total, payment) async {
                  submitted = true;
                }))));
    await tester.pumpAndSettle();
    expect(find.text('Price unavailable'), findsOneWidget);
    expect(find.text('A product price needs to be updated by the shop.'),
        findsOneWidget);
    final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Checkout Order'));
    expect(button.onPressed, isNull);
    expect(submitted, isFalse);
    expect(tester.takeException(), isNull);
  });
}
