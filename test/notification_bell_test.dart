import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printingshop/services/app_notifications.dart';
import 'package:printingshop/widgets/notification_bell.dart';

class FakeNotifications extends NotificationRepository {
  FakeNotifications() : super(uid: 'u1', email: 'a@example.com', admin: false);
  final controller = StreamController<List<InboxNotification>>.broadcast();
  List<InboxNotification> items = [
    InboxNotification('n1',
        {'title': 'Ready for Pickup', 'message': 'Order PRNT-123456 is ready.'},
        unread: true),
  ];
  @override
  Stream<List<InboxNotification>> watch() => controller.stream;
  @override
  Future<void> markRead(List<InboxNotification> selected) async {
    final ids = selected.map((item) => item.id).toSet();
    items = items
        .map((item) => ids.contains(item.id)
            ? InboxNotification(item.id, item.data, unread: false)
            : item)
        .toList();
    controller.add(items);
  }

  @override
  Future<void> clear(List<InboxNotification> selected) async {
    final ids = selected.map((item) => item.id).toSet();
    items.removeWhere((item) => ids.contains(item.id));
    controller.add(items);
  }
}

void main() {
  test('state overlays hide dismissed records and preserve legacy read flags',
      () {
    final result = visibleNotifications({
      'old': {'status': 'Read', 'timestamp': '2026-11-01'},
      'new': {'timestamp': '2026-11-08'},
      'hidden': {},
      'read': {},
    }, {
      'hidden': {'dismissed': true},
      'read': {'read': true}
    });
    expect(result.map((item) => item.id), ['new', 'old', 'read']);
    expect(result.where((item) => item.unread).length, 1);
  });

  testWidgets('bell, list, mark read and clear fit a small phone',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = FakeNotifications();
    addTearDown(repo.controller.close);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            appBar: AppBar(actions: [
      NotificationBell(repository: repo, onOpen: (_) {}),
    ]))));
    repo.controller.add(repo.items);
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
    expect(find.text('Ready for Pickup'), findsOneWidget);
    await tester.tap(find.text('Mark read'));
    await tester.pumpAndSettle();
    expect(repo.items.single.unread, false);
    await tester.tap(find.text('Clear all'));
    await tester.pumpAndSettle();
    expect(find.text('No notifications yet.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an error before opening the panel remains visible and can retry',
      (tester) async {
    final repo = FakeNotifications();
    addTearDown(repo.controller.close);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            appBar: AppBar(actions: [
      NotificationBell(repository: repo, onOpen: (_) {}),
    ]))));
    repo.controller.addError(StateError('permission denied'));
    await tester.pump();
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    repo.controller.add(repo.items);
    await tester.pumpAndSettle();
    expect(find.text('Ready for Pickup'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('notification tap marks read and opens its destination',
      (tester) async {
    final repo = FakeNotifications();
    addTearDown(repo.controller.close);
    InboxNotification? opened;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            appBar: AppBar(actions: [
      NotificationBell(repository: repo, onOpen: (item) => opened = item),
    ]))));
    repo.controller.add(repo.items);
    await tester.pump();
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ready for Pickup'));
    await tester.pumpAndSettle();
    expect(opened?.id, 'n1');
    expect(repo.items.single.unread, false);
    expect(find.text('Mark read'), findsNothing);
  });
}
