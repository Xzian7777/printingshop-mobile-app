import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printingshop/screens/admin_pos_view.dart';
import 'package:printingshop/services/pos_repository.dart';
import 'package:printingshop/services/pos_rules.dart';
import 'package:printingshop/theme/dashboard_theme.dart';

class FakePos extends PosRepository {
  Map<String, dynamic>? draft, sale;
  final attempts = <Map<String, dynamic>>[];
  bool failOnce = false;
  @override
  String get cashier => 'admin1';
  @override
  Future<Map<String, dynamic>?> getDraft() async => draft;
  @override
  Future<void> saveDraft(Map<String, dynamic> payload) async {
    draft = payload;
  }

  @override
  Future<void> clearDraft() async {
    draft = null;
  }

  @override
  Future<List<Map<String, dynamic>>> catalog() async => [
        {
          'id': 'p1',
          'kind': 'product',
          'name': 'Notebook',
          'price': 19,
          'stock': 5
        },
        {
          'id': 's1',
          'kind': 'service',
          'name': 'Document Printing',
          'price': 3
        },
      ];
  @override
  Future<List<Map<String, dynamic>>> history() async =>
      sale == null ? [] : [sale!];
  @override
  Future<Map<String, dynamic>> complete(Map<String, dynamic> request) async {
    attempts.add(request);
    if (failOnce) {
      failOnce = false;
      throw Exception('network interrupted');
    }
    final result = validatePosSale(request,
        {for (final x in await catalog()) '${x['kind']}/${x['id']}': x});
    sale = {...result, 'id': 'POS-123456', 'createdAt': '2026-11-07T01:00:00Z'};
    return sale!;
  }
}

void main() {
  Finder field(String label) => find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == label);
  Future<void> open(WidgetTester tester, FakePos repo) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: DashboardTheme.light,
        home: Scaffold(body: AdminPosView(repository: repo))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notebook').first);
    await tester.pumpAndSettle();
  }

  testWidgets(
      'cash counter sale saves buyer, selected quantity, total and change',
      (tester) async {
    final repo = FakePos();
    await open(tester, repo);
    await tester.ensureVisible(field('Buyer name'));
    await tester.enterText(field('Buyer name'), 'Juan Dela Cruz');
    await tester.ensureVisible(field('Quantity'));
    await tester.enterText(field('Quantity'), '2');
    await tester.ensureVisible(field('Cash received'));
    await tester.enterText(field('Cash received'), '100');
    await tester.pumpAndSettle();
    expect(find.text('₱62.00'), findsOneWidget);
    await tester.ensureVisible(find.text('Complete sale'));
    await tester.tap(find.text('Complete sale'));
    await tester.pumpAndSettle();
    expect(repo.sale?['buyerName'], 'Juan Dela Cruz');
    expect(repo.sale?['total'], 38);
    expect(repo.sale?['change'], 62);
    expect(repo.draft, isNull);
    expect(find.text('Print receipt'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'unknown result preserves the same sale and locks edits until retry',
      (tester) async {
    final repo = FakePos()..failOnce = true;
    await open(tester, repo);
    await tester.ensureVisible(field('Cash received'));
    await tester.enterText(field('Cash received'), '100');
    await tester.ensureVisible(find.text('Complete sale'));
    await tester.tap(find.text('Complete sale'));
    await tester.pumpAndSettle();
    expect(repo.draft, isNotNull);
    expect(tester.widget<TextField>(field('Buyer name')).enabled, isFalse);
    await tester.ensureVisible(find.text('Retry same sale'));
    await tester.tap(find.text('Retry same sale'));
    await tester.pumpAndSettle();
    expect(repo.attempts.length, 2);
    expect(repo.attempts[0]['submissionId'], repo.attempts[1]['submissionId']);
    expect(repo.draft, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('insufficient cash leaves the sale editable and unsaved',
      (tester) async {
    final repo = FakePos();
    await open(tester, repo);
    await tester.ensureVisible(field('Cash received'));
    await tester.enterText(field('Cash received'), '1');
    await tester.ensureVisible(find.text('Complete sale'));
    await tester.tap(find.text('Complete sale'));
    await tester.pumpAndSettle();
    expect(repo.attempts, isEmpty);
    expect(repo.draft, isNull);
    expect(find.text('Cash received must cover the total.'), findsOneWidget);
    expect(tester.widget<TextField>(field('Buyer name')).enabled, isTrue);
    expect(tester.takeException(), isNull);
  });
}
