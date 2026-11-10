import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printingshop/widgets/store_checkout_sheet.dart';
import 'package:printingshop/widgets/store_product_card.dart';
import 'package:printingshop/services/order_validation.dart';
import 'package:printingshop/theme/dashboard_theme.dart';

const captureStorePreview = bool.fromEnvironment('CAPTURE_STORE_PREVIEW');

Future<void> captureStore(WidgetTester tester, String name) async {
  if (!captureStorePreview) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byType(RepaintBoundary).first);
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/ui-review/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    if (!captureStorePreview) return;
    final file = File('.dart_tool/package_config.json');
    final config = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final flutter = (config['packages'] as List)
        .firstWhere((package) => package['name'] == 'flutter') as Map;
    final root = file.absolute.uri.resolve('${flutter['rootUri']}/');
    for (final entry in {
      'Roboto': 'roboto-regular.ttf',
      'MaterialIcons': 'materialicons-regular.otf'
    }.entries) {
      final font = File.fromUri(root
          .resolve('../../bin/cache/artifacts/material_fonts/${entry.value}'));
      final loader = FontLoader(entry.key)
        ..addFont(Future.value(ByteData.sublistView(font.readAsBytesSync())));
      await loader.load();
    }
  });
  const merchant = {
    'accountName': 'Printing Shop',
    'accountNumber': '09123456789',
    'isActive': true,
    'qrUrl': ''
  };
  test('store and printing share GCash reference validation', () {
    expect(OrderValidation.validatePayment('GCash', ''), isNotNull);
    expect(OrderValidation.validatePayment('GCash', '1234567890123'), isNull);
    expect(OrderValidation.validatePayment('GCash Online', '12345678'), isNull);
    expect(OrderValidation.validatePayment('Paymaya', ''), isNotNull);
    expect(OrderValidation.validatePayment('Cash on Pickup', ''), isNull);
  });

  test('shared QR ignores an image belonging to an older QR setting', () {
    expect(
        gcashQrSource({
          'qrUrl': 'new.png',
          'qrImageSource': 'old.png',
          'qrImageData': 'old-data'
        }),
        'new.png');
    expect(
        gcashQrSource({
          'qrUrl': 'same.png',
          'qrImageSource': 'same.png',
          'qrImageData': 'current-data'
        }),
        'current-data');
  });

  testWidgets(
      'store GCash requires a reference and passes merchant details to checkout',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    StorePaymentDetails? sent;
    await tester.pumpWidget(MaterialApp(
        theme: DashboardTheme.light,
        home: Scaffold(
            body: StoreCheckoutSheet(
          cart: const {'p1': 1},
          products: const {
            'p1': {'name': 'Notebook', 'price': 19, 'stock': 12}
          },
          merchantSettings: Stream.value(merchant),
          onCartChanged: (_) {},
          onCheckout: (context, entries, total, payment) async {
            sent = payment;
            expect(total, 19);
          },
        ))));
    await tester.pumpAndSettle();
    expect(find.text('Paymaya'), findsNothing);
    await tester.tap(find.text('GCash'));
    await tester.pumpAndSettle();
    expect(find.text('09123456789'), findsOneWidget);
    await tester.tap(find.text('Checkout Order'));
    await tester.pumpAndSettle();
    expect(sent, isNull);
    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), '1234567890123');
    await tester.pumpAndSettle();
    await captureStore(tester, 'mobile-store-gcash');
    await tester.tap(find.text('Checkout Order'));
    await tester.pumpAndSettle();
    expect(sent?.method, 'GCash');
    expect(sent?.reference, '1234567890123');
    expect(sent?.merchantAccount, '09123456789');
    expect(sent?.receipt, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cash remains available when merchant settings are disabled',
      (tester) async {
    StorePaymentDetails? sent;
    await tester.pumpWidget(MaterialApp(
        theme: DashboardTheme.light,
        home: Scaffold(
            body: StoreCheckoutSheet(
          cart: const {'p1': 1},
          products: const {
            'p1': {'name': 'Notebook', 'price': 19, 'stock': 1}
          },
          merchantSettings: Stream.value({...merchant, 'isActive': false}),
          onCartChanged: (_) {},
          onCheckout: (context, entries, total, payment) async {
            sent = payment;
          },
        ))));
    await tester.pumpAndSettle();
    final chip = tester.widget<ChoiceChip>(find.ancestor(
        of: find.text('GCash'), matching: find.byType(ChoiceChip)));
    expect(chip.onSelected, isNull);
    await tester.tap(find.text('Checkout Order'));
    await tester.pumpAndSettle();
    expect(sent?.method, 'Cash on Pickup');
    expect(sent?.reference, '');
  });

  testWidgets('narrow store cards open details without direct purchase buttons',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var actions = 0;
    await tester.pumpWidget(MaterialApp(
        theme: DashboardTheme.light,
        home: Scaffold(
            body: GridView.count(
          crossAxisCount: 2,
          childAspectRatio: 0.45,
          padding: const EdgeInsets.all(12),
          children: [
            StoreProductCard(
                name: 'Notebook',
                price: 999999,
                stock: 0,
                image: const Icon(Icons.inventory_2_outlined),
                onOpen: () => actions++),
            StoreProductCard(
                name: 'Wagyu',
                price: 999999,
                stock: 12,
                image: const Icon(Icons.inventory_2_outlined),
                onOpen: () => actions++),
          ],
        ))));
    await tester.pumpAndSettle();
    expect(find.text('Out of Stock'), findsOneWidget);
    expect(find.text('Low Stock'), findsOneWidget);
    await captureStore(tester, 'mobile-store-products');
    expect(find.text('Add to Cart'), findsNothing);
    expect(find.text('Buy Now'), findsNothing);
    await tester.tap(find.text('Notebook'));
    await tester.tap(find.text('Wagyu'));
    expect(actions, 2);
    expect(tester.takeException(), isNull);
  });
}
