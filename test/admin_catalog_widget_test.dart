import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printingshop/screens/admin_catalog_view.dart';

void main() {
  testWidgets(
      'service editor validates required fields without contacting Firebase',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: AdminCatalogEditor(services: true, id: null, initial: {}))));
    final save = find.widgetWithText(FilledButton, 'Save');
    await tester.tap(save);
    await tester.pump();
    expect(find.text('Required'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'service requirements preserve labels, choices and required state',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: AdminCatalogEditor(services: true, id: 'custom', initial: {
      'name': 'Custom print',
      'basePrice': 25,
      'unit': '/piece',
      'sortOrder': 2,
      'requirements': [
        {
          'label': 'Finish',
          'type': 'select',
          'required': true,
          'options': ['Gloss', 'Matte']
        }
      ],
    }))));
    expect(find.text('Custom print'), findsOneWidget);
    final scroll = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('Required').first, 200,
        scrollable: scroll);
    expect(find.text('Finish'), findsOneWidget);
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue);
    expect(find.text('Gloss\nMatte'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('samples retain display price strings and service linkage',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: AdminCatalogEditor(services: false, id: 'sample', initial: {
      'title': 'Waterproof stickers',
      'category': 'Stickers',
      'serviceVal': 'stickers',
      'price': 'Starts at ₱5 / pc',
      'badge': 'Waterproof',
    }))));
    expect(find.text('Waterproof stickers'), findsOneWidget);
    expect(find.text('stickers'), findsOneWidget);
    expect(find.text('Starts at ₱5 / pc'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
