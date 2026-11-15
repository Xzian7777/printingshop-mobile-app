import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printingshop/widgets/dashboard_controls.dart';

void main() {
  testWidgets('Action notices wrap on a narrow screen with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
      child: const ActionNotice(message: 'You approved order PRNT-654923.'),
    ))));
    expect(find.text('You approved order PRNT-654923.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Logout shows progress and blocks duplicate actions until completion', (tester) async {
    final pending = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) =>
      TextButton(onPressed: () => showDialog(context: context,
        builder: (_) => LogoutConfirmationDialog(onLogout: () {
          calls++;
          return pending.future;
        })), child: const Text('Open')))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log Out'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'Cancel')).onPressed, isNull);
    expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed, isNull);
    expect(calls, 1);
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.byType(LogoutConfirmationDialog), findsNothing);
  });

  testWidgets('Failed logout restores retry controls and readable feedback', (tester) async {
    await tester.pumpWidget(MaterialApp(home: LogoutConfirmationDialog(
      onLogout: () async => throw StateError('offline'),
    )));
    await tester.tap(find.text('Log Out'));
    await tester.pumpAndSettle();
    expect(find.text('Unable to log out. Please try again.'), findsOneWidget);
    expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed, isNotNull);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
