import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printingshop/services/payment_eligibility.dart';
import 'package:printingshop/widgets/store_checkout_sheet.dart';
import 'package:printingshop/screens/place_order_screen.dart';

void main() {
  testWidgets('new store customer sees locked cash and GCash selected',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: StoreCheckoutSheet(
      paymentEligibility: Future.value(const PaymentEligibility(
          cashOnPickupAllowed: false, hasOrders: false)),
      cart: const {'p1': 1},
      products: const {
        'p1': {'name': 'Notebook', 'price': 25, 'stock': 10}
      },
      merchantSettings: Stream.value(
          const {'isActive': true, 'accountNumber': '09123456789'}),
      onCartChanged: (_) {},
      onCheckout: (_, entries, total, payment) async {},
    ))));
    await tester.pumpAndSettle();
    final cash = tester
        .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Cash on Pickup'));
    expect(cash.onSelected, isNull);
    expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'GCash'))
            .selected,
        isTrue);
    expect(find.text(PaymentEligibility.lockedMessage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('new printing customer cannot choose cash', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: PlaceOrderScreen(
      userEmail: 'new@example.com',
      paymentEligibility: Future.value(const PaymentEligibility(
          cashOnPickupAllowed: false, hasOrders: false)),
    )));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Cash on Pickup').first);
    await tester.tap(find.text('Cash on Pickup').first);
    await tester.pumpAndSettle();
    expect(find.text('GCash Reference Number'), findsOneWidget);
    expect(find.text(PaymentEligibility.lockedMessage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
