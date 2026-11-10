import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printingshop/screens/place_order_screen.dart';

void main() {
  testWidgets('GCash reference field is shown only for GCash payment',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: PlaceOrderScreen(userEmail: 'customer@example.com'),
    ));
    expect(find.text('GCash Reference Number'), findsOneWidget);
    await tester.ensureVisible(find.text('Cash on Pickup').first);
    await tester.tap(find.text('Cash on Pickup').first);
    await tester.pumpAndSettle();
    expect(find.text('GCash Reference Number'), findsNothing);
    await tester.tap(find.text('GCash Online').first);
    await tester.pumpAndSettle();
    expect(find.text('GCash Reference Number'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing attachment blocks submission before Firebase access',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: PlaceOrderScreen(userEmail: 'customer@example.com'),
    ));
    final submit =
        find.widgetWithText(ElevatedButton, 'Confirm & Submit Order →');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    expect(
        find.text(
            'Please upload your document or design file in Step 1 before submitting the order!'),
        findsOneWidget);
    expect(find.text('Uploading & Submitting...'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
