import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printingshop/widgets/points_selector.dart';

void main() {
  testWidgets(
      'whole points are capped at half the subtotal and show net payment',
      (tester) async {
    var points = 0;
    var discount = 0.0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: PointsSelector(
      subtotal: 99,
      customer: const {'uid': 'u1', 'available': 100, 'pointValueCents': 100},
      onChanged: (value) => points = value,
      onDiscountChanged: (value) => discount = value,
    )))));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '999999');
    await tester.pumpAndSettle();
    expect(points, 49);
    expect(discount, 49);
    expect(find.text('To pay ₱50.00'), findsOneWidget);
    expect(find.text('Available after reservation 51 points'), findsOneWidget);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(points, 0);
    expect(discount, 0);
  });

  testWidgets('custom conversion and small phone layout remain readable',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var points = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: PointsSelector(
      subtotal: 100,
      customer: const {'uid': 'u1', 'available': 100, 'pointValueCents': 200},
      onChanged: (value) => points = value,
    )))));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '100');
    await tester.pumpAndSettle();
    expect(points, 25);
    expect(find.text('To pay ₱50.00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty balance disables redemption', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: PointsSelector(
      subtotal: 100,
      customer: const {'uid': 'u1', 'available': 0, 'pointValueCents': 100},
      onChanged: (_) {},
    ))));
    await tester.pumpAndSettle();
    final toggle = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(toggle.onChanged, isNull);
    expect(find.byType(TextField), findsNothing);
  });
}
