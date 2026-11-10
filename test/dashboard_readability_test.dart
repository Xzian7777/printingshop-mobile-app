import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printingshop/theme/dashboard_theme.dart';
import 'package:printingshop/widgets/dashboard_controls.dart';
import 'package:printingshop/widgets/customer_order_card.dart';

const capturePreview = bool.fromEnvironment('CAPTURE_DASHBOARD_PREVIEW');
final previewKey = GlobalKey();

Widget preview(
        {bool hasFile = false,
        ValueChanged<String>? onAction,
        VoidCallback? onTerms}) =>
    RepaintBoundary(
      key: previewKey,
      child: MaterialApp(
          theme: ThemeData.dark(),
          home: Theme(
              data: DashboardTheme.light,
              child: Scaffold(
                appBar: AppBar(title: const Text('KCZ Printing (Admin)')),
                body: Column(children: [
                  Expanded(
                      child: AdminProfilePanel(
                          email: 'supernovaelectrodog@gmail.com',
                          onTerms: onTerms ?? () {})),
                  Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(children: [
                        Expanded(
                            child: ElevatedButton(
                                onPressed: () {},
                                child: const Text('View Orders'))),
                        const SizedBox(width: 10),
                        Expanded(child: StoreSuppliesButton(onPressed: () {})),
                      ])),
                  Padding(
                      padding: const EdgeInsets.all(16),
                      child: Align(
                          alignment: Alignment.centerRight,
                          child: OrderOptionsButton(
                              hasFile: hasFile,
                              onSelected: onAction ?? (_) {}))),
                ]),
              ))),
    );

Future<void> capture(WidgetTester tester, String name) async {
  if (!capturePreview) return;
  debugDisableShadows = false;
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final boundary =
        previewKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/ui-review/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
  debugDisableShadows = true;
}

void main() {
  testWidgets(
      'long store order cards fit narrow screens and show customer options',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? selected;
    await tester.pumpWidget(RepaintBoundary(
        key: previewKey,
        child: MaterialApp(
            theme: DashboardTheme.light,
            home: Scaffold(
                appBar: AppBar(title: const Text('My Orders')),
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: CustomerOrderCard(
                      reference: 'PRNT-yZ1kwfEMNyLG1FLLmlA9',
                      order: const {
                        'service': 'In-Store: acer (1x)',
                        'paperSize': 'Store Supply',
                        'total': 15000,
                        'payment': 'GCash',
                        'status': 'Order Submitted',
                        'file': 'Store_Receipt.pdf',
                        'items': [
                          {'name': 'acer', 'qty': 1}
                        ]
                      },
                      dateLabel: 'Nov 7, 2026 • 08:36 AM',
                      specsLabel: 'Store Supply • 1 copy',
                      timeline:
                          const OrderTimeline(currentStage: 0, store: true),
                      onAction: (value) => selected = value),
                )))));
    await tester.pumpAndSettle();
    expect(find.text('₱15,000.00'), findsOneWidget);
    expect(find.text('Store Supply • 1 copy'), findsNothing);
    expect(find.text('Preparing'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture(tester, 'customer-order-card');
    await tester.tap(find.byTooltip('Order Options'));
    await tester.pumpAndSettle();
    expect(find.text('Review Specs & File'), findsOneWidget);
    expect(find.text('Reject Order'), findsNothing);
    expect(find.text('Delete Order'), findsNothing);
    expect(find.text('Cancel Order'), findsOneWidget);
    await capture(tester, 'customer-order-options');
    await tester.tap(find.text('Review Specs & File'));
    await tester.pumpAndSettle();
    expect(selected, 'review');
    expect(tester.takeException(), isNull);
  });

  testWidgets('large text and long printing titles wrap inside order cards',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: DashboardTheme.light,
        home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: Scaffold(
                body: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: CustomerOrderCard(
                      reference: 'PRNT-123456',
                      order: const {
                        'service':
                            'Document Printing with a long customized service name',
                        'payment': 'Cash on Pickup',
                        'total': 1000000,
                        'status': 'Approved',
                        'fileName': 'a-very-long-document-filename.pdf',
                        'fileUrl': 'https://example.com/test.pdf'
                      },
                      dateLabel: 'Nov 7, 2026 • 08:36 AM',
                      specsLabel: 'A4 • 100 copies',
                      timeline: const OrderTimeline(currentStage: 1),
                      onAction: (_) {},
                    ))))));
    await tester.pumpAndSettle();
    expect(find.text('₱1,000,000.00'), findsOneWidget);
    expect(find.text('Printing'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  setUpAll(() async {
    if (!capturePreview) return;
    final configFile = File('.dart_tool/package_config.json');
    final config =
        jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
    final flutter = (config['packages'] as List)
        .firstWhere((p) => p['name'] == 'flutter') as Map;
    final root = configFile.absolute.uri.resolve('${flutter['rootUri']}/');
    final fonts = root.resolve('../../bin/cache/artifacts/material_fonts/');
    for (final entry in {
      'Roboto': 'roboto-regular.ttf',
      'monospace': 'roboto-regular.ttf',
      'MaterialIcons': 'materialicons-regular.otf'
    }.entries) {
      final file = File.fromUri(fonts.resolve(entry.value));
      if (file.existsSync()) {
        final loader = FontLoader(entry.key)
          ..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
        await loader.load();
      }
    }
  });

  test('small text and button colors meet 4.5:1 contrast on light surfaces',
      () {
    double ratio(Color a, Color b) {
      final x = a.computeLuminance(), y = b.computeLuminance();
      return ((x > y ? x : y) + 0.05) / ((x > y ? y : x) + 0.05);
    }

    for (final background in [
      Colors.white,
      DashboardTheme.canvas,
      const Color(0xFFF0FDF4)
    ]) {
      for (final foreground in [
        DashboardTheme.ink,
        DashboardTheme.muted,
        DashboardTheme.green,
        const Color(0xFFBE123C)
      ]) {
        expect(ratio(foreground, background), greaterThanOrEqualTo(4.5));
      }
    }
    expect(
        ratio(Colors.white, DashboardTheme.green), greaterThanOrEqualTo(4.5));
  });

  testWidgets('profile and store button stay readable under a dark parent',
      (tester) async {
    if (capturePreview) debugDisableShadows = false;
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var termsOpened = false;
    await tester.pumpWidget(preview(onTerms: () => termsOpened = true));
    await tester.pumpAndSettle();
    expect(find.text('Administrator Profile'), findsOneWidget);
    expect(find.text('Terms and Conditions'), findsOneWidget);
    expect(find.text('Store Supplies'), findsOneWidget);
    await capture(tester, 'dashboard-profile-home');
    await tester.tap(find.text('Terms and Conditions'));
    expect(termsOpened, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'order menu shows all actions and preserves disabled attachment behavior',
      (tester) async {
    if (capturePreview) debugDisableShadows = false;
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? action;
    await tester.pumpWidget(preview(onAction: (value) => action = value));
    await tester.tap(find.byTooltip('Order Options'));
    await tester.pumpAndSettle();
    expect(find.text('Review Specs & File'), findsOneWidget);
    expect(find.text('Open Attached File'), findsOneWidget);
    expect(find.text('Print Job Slip'), findsOneWidget);
    expect(find.text('Reject Order'), findsOneWidget);
    final fileItem = find.ancestor(
        of: find.text('Open Attached File'),
        matching: find.byType(PopupMenuItem<String>));
    expect(tester.widget<PopupMenuItem<String>>(fileItem).enabled, isFalse);
    await capture(tester, 'dashboard-order-menu');
    await tester.tap(find.text('Review Specs & File'));
    await tester.pumpAndSettle();
    expect(action, 'review');
    expect(tester.takeException(), isNull);
  });
}
