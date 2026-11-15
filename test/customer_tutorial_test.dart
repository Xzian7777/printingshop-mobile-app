import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printingshop/widgets/customer_tutorial.dart';

void main() {
  testWidgets('tutorial navigates through payment and tracking instructions',
      (tester) async {
    bool? finished;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () async {
                        finished = await showDialog<bool>(
                            context: context,
                            builder: (_) => const CustomerTutorial());
                      },
                      child: const Text('Open tutorial')),
                ))));
    await tester.tap(find.text('Open tutorial'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Kez C-Em Zek'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Cash on Pickup unlocks'), findsOneWidget);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Choose your service or supplies'), findsOneWidget);
    for (var index = 0; index < 3; index++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(finished, isTrue);
  });

  testWidgets(
      'tutorial fits a narrow screen with enlarged text and can be skipped',
      (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!),
        home: const Scaffold(body: CustomerTutorial())));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Skip tutorial'), findsOneWidget);
  });
}
