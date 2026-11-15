import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printingshop/screens/rewards_screen.dart';
import 'package:printingshop/screens/admin_rfid_loyalty_view.dart';
import 'package:printingshop/services/profile_directory.dart';

Future<Map<String, dynamic>> catalog() async => {
      'products': [
        {'id': 'p1', 'name': 'Notebook'}
      ],
      'services': [
        {'id': 'tarpaulins', 'name': 'Tarpaulin', 'requirements': []}
      ],
    };

Future<Map<String, dynamic>> rewards(String path) async =>
    path.contains('settings')
        ? {
            'success': true,
            'settings': {'pointValueCents': 150}
          }
        : {
            'success': true,
            'rewards': [
              {
                'id': 'r1',
                'name': 'Free notebook',
                'description': 'One notebook',
                'pointsCost': 50,
                'quantity': 1,
                'active': true
              },
            ]
          };

void main() {
  testWidgets(
      'Reward editor and service requirements stay light under a dark app',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!),
        home: RewardEditor(catalogLoader: catalog)));
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.byType(TextField).first)).brightness,
        Brightness.light);
    await tester.tap(find.text('Catalog product or service'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tarpaulin (service)').last);
    await tester.pumpAndSettle();
    expect(find.text('Pages per package'), findsOneWidget);
    expect(find.text('Width in feet'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Height in feet'), 160,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Height in feet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Editing a printing reward retains its package fields',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        home: RewardEditor(
          catalogLoader: catalog,
          initial: const {
            'id': 'r1',
            'name': 'Free tarp',
            'pointsCost': 5,
            'quantity': 1,
            'pages': 2,
            'active': true,
            'kind': 'service',
            'catalogId': 'tarpaulins',
            'specifications': {'dimensions': '2ft x 3ft'},
          },
        )));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Height in feet'), 160,
        scrollable: find.byType(Scrollable).first);
    final width = tester
        .widget<TextField>(find.widgetWithText(TextField, 'Width in feet'));
    final height = tester
        .widget<TextField>(find.widgetWithText(TextField, 'Height in feet'));
    expect(width.controller!.text, '2');
    expect(height.controller!.text, '3');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Embedded rewards use the parent scroll and a light conversion dialog',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: SingleChildScrollView(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: RewardsScreen(
                      isAdmin: true, embedded: true, loadData: rewards))),
        )));
    await tester.pumpAndSettle();
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('Rewards Management'), findsOneWidget);
    expect(find.text('Available for redemption'), findsOneWidget);
    expect(find.textContaining('1 point = ₱1.50'), findsOneWidget);
    final list = tester.widget<ListView>(find.byType(ListView));
    expect(list.shrinkWrap, isTrue);
    expect(list.physics, isA<NeverScrollableScrollPhysics>());
    await tester.tap(find.textContaining('Edit conversion'));
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.text('Value of one point'))).brightness,
        Brightness.light);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  test('Duplicate profiles retain canonical identity and expose legacy IDs',
      () {
    final user = ProfileRecord('u1', {
      'uid': 'u1',
      'email': 'person@example.com',
      'full_name': 'Canonical customer',
      'role': 'customer'
    });
    final legacy = [
      for (final id in ['a', 'b', 'c'])
        ProfileRecord(id, {
          'uid': 'u1',
          'email': 'person@example.com',
          'fullName': 'Old name',
          'rfidUid': 'card-$id'
        })
    ];
    final rows = mergeProfiles([user], legacy);
    expect(rows, hasLength(1));
    expect(rows.single.id, 'u1');
    expect(rows.single.data()['fullName'], 'Canonical customer');
    expect(rows.single.data()['legacyCustomerIds'], ['a', 'b', 'c']);
    expect(rows.single.data()['rfidReviewRequired'], isTrue);
    expect(rows.single.data()['rfidUid'], '');
    expect(legacy.first.data()['rfidUid'], 'card-a');
  });

  test('Profiles with different explicit UIDs remain separate', () {
    final users = [
      for (final uid in ['u1', 'u2'])
        ProfileRecord(
            uid, {'uid': uid, 'email': 'same@example.com', 'role': 'customer'})
    ];
    expect(mergeProfiles(users, []), hasLength(2));
  });
  testWidgets('RFID review cards fit long identifiers and large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!),
      home: const Scaffold(
          body: SingleChildScrollView(
              child: LoyaltyMemberCard(
        pointsUnavailable: false,
        card: {
          'cardUid': 'RFID-KCZ-12345678901234567890',
          'name': 'Customer with a long registered name',
          'email': 'customer.long.email@example.com',
          'points': 12000,
          'rfidReviewRequired': true,
          'legacyCustomerIds': [
            'CUST-167',
            'CUST-1791408101',
            'CUST-1793489874'
          ],
        },
      ))),
    ));
    await tester.pumpAndSettle();
    expect(find.text('RFID review required'), findsOneWidget);
    expect(find.text('12000 available points'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
