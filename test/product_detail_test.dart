import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printingshop/screens/product_detail_screen.dart';
import 'package:printingshop/theme/dashboard_theme.dart';

void main() {
  Future<void> openProduct(WidgetTester tester,
      {int stock = 3,
      int cartQuantity = 0,
      double price = 19,
      ValueChanged<int>? onAdd,
      ValueChanged<int>? onBuy}) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: DashboardTheme.light,
      home: Scaffold(
          body: Builder(
              builder: (context) => TextButton(
                    onPressed: () => ProductDetailScreen.showOverviewDialog(
                      context,
                      productId: 'p1',
                      productData: {
                        'name': 'Notebook',
                        'price': price,
                        'stock': stock
                      },
                      cartQuantity: cartQuantity,
                      onAddToCart: onAdd,
                      onBuyNow: (quantity) {
                        onBuy?.call(quantity);
                        showModalBottomSheet(
                            context: context,
                            builder: (_) => const Text('Checkout is open'));
                      },
                    ),
                    child: const Text('Open product'),
                  ))),
    ));
    await tester.tap(find.text('Open product'));
    await tester.pumpAndSettle();
  }

  String total(WidgetTester tester) => tester
      .widget<Text>(find.byKey(const ValueKey('productTotalPrice')))
      .data!;

  testWidgets('quantity changes the total and stays within stock',
      (tester) async {
    int? added;
    await openProduct(tester, onAdd: (quantity) => added = quantity);
    expect(total(tester), '₱19.00');
    await tester.ensureVisible(find.byIcon(Icons.add));
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(total(tester), '₱38.00');
    await tester.tap(find.byIcon(Icons.add));
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(total(tester), '₱57.00');
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pumpAndSettle();
    expect(total(tester), '₱38.00');
    await tester.ensureVisible(find.text('Add to Cart'));
    await tester.tap(find.text('Add to Cart'));
    await tester.pumpAndSettle();
    expect(added, 2);
    expect(find.byType(ProductDetailScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cart stock guard keeps the product open on failure',
      (tester) async {
    var added = false;
    await openProduct(tester,
        stock: 1, cartQuantity: 1, onAdd: (_) => added = true);
    await tester.ensureVisible(find.text('Add to Cart'));
    await tester.tap(find.text('Add to Cart'));
    await tester.pumpAndSettle();
    expect(added, isFalse);
    expect(find.byType(ProductDetailScreen), findsOneWidget);
    expect(find.textContaining('already have 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('buy now closes the product before opening checkout',
      (tester) async {
    int? bought;
    await openProduct(tester, onBuy: (quantity) => bought = quantity);
    await tester.ensureVisible(find.byIcon(Icons.add));
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Buy Now'));
    await tester.tap(find.text('Buy Now'));
    await tester.pumpAndSettle();
    expect(bought, 2);
    expect(find.byType(ProductDetailScreen), findsNothing);
    expect(find.text('Checkout is open'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sold-out total is zero and large totals fit a narrow dialog',
      (tester) async {
    await openProduct(tester, stock: 0);
    expect(total(tester), '₱0.00');
    await tester.ensureVisible(find.text('Buy Now'));
    final button = tester.widget<ElevatedButton>(find.ancestor(
        of: find.text('Buy Now'), matching: find.byType(ElevatedButton)));
    expect(button.onPressed, isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await openProduct(tester, stock: 100000, price: 999999);
    await tester.ensureVisible(find.byIcon(Icons.add));
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(total(tester), '₱1,999,998.00');
    expect(tester.takeException(), isNull);
  });
}
