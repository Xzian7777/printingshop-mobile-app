import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class InboxNotification {
  final String id;
  final Map<String, dynamic> data;
  final bool unread;
  InboxNotification(this.id, this.data, {required this.unread});
  String get title => '${data['title'] ?? 'Shop update'}';
  String get message {
    final value = '${data['message'] ?? ''}';
    if (data['type'] == 'order_status' || title.startsWith('Order Status:')) {
      final match = RegExp(r'^Ang iyong (.+) ay nasa status na: (.+)\.$')
          .firstMatch(value);
      if (match != null) return 'Your ${match[1]} is now ${match[2]}.';
    }
    return value;
  }

  DateTime get time {
    final value = data['createdAt'] ?? data['timestamp'];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse('$value') ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  Map<String, dynamic> get destination => {
        ...data,
        'click_url': data['link'] ?? '/',
        if (data['conversationId'] != null)
          'conversation_id': data['conversationId'],
      };
}

List<InboxNotification> visibleNotifications(
    Map<String, Map<String, dynamic>> records,
    Map<String, Map<String, dynamic>> states) {
  final result = <InboxNotification>[];
  for (final entry in records.entries) {
    final state = states[entry.key] ?? {};
    if (state['dismissed'] == true) continue;
    final read = state['read'] == true ||
        '${entry.value['status'] ?? ''}'.toLowerCase() == 'read';
    result.add(InboxNotification(entry.key, entry.value, unread: !read));
  }
  result.sort((a, b) {
    final order = b.time.compareTo(a.time);
    return order == 0 ? a.id.compareTo(b.id) : order;
  });
  return result;
}

Map<String, dynamic> notificationRecord(
        {required String id,
        required String recipient,
        required String title,
        required String message,
        required String type,
        required String link,
        String? email,
        String? orderId,
        String? conversationId,
        String? messageId}) =>
    {
      'id': id,
      'userId': recipient,
      'title': title,
      'message': message,
      'type': type,
      'link': link,
      'status': 'Unread',
      'createdAt': FieldValue.serverTimestamp(),
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      if (email != null && email.isNotEmpty)
        'recipientEmail': email.trim().toLowerCase(),
      if (orderId != null) 'orderId': orderId,
      if (conversationId != null) 'conversationId': conversationId,
      if (messageId != null) 'messageId': messageId,
    };

void addNewOrderNotification(Transaction tx, FirebaseFirestore db, String id,
    Map<String, dynamic> order) {
  final key = 'order_created_$id';
  tx.set(
      db.collection('notifications').doc(key),
      notificationRecord(
          id: key,
          recipient: 'ADMIN',
          title: 'New Order: $id',
          message:
              '${order['customerName'] ?? order['customer'] ?? 'Customer'} placed an order.',
          type: 'new_order',
          orderId: id,
          link: '/admin'));
}

class NotificationRepository {
  final String uid, email;
  final bool admin;
  NotificationRepository(
      {required this.uid, required this.email, required this.admin});
  FirebaseFirestore get db => FirebaseFirestore.instance;
  String get identity => '$uid|${email.toLowerCase()}|$admin';

  Stream<List<InboxNotification>> watch() {
    final selectors = {
      uid,
      email.trim().toLowerCase(),
      'ALL',
      if (admin) 'ADMIN'
    }..remove('');
    final sources = <Stream<QuerySnapshot<Map<String, dynamic>>>>[
      db
          .collection('notifications')
          .where('userId', whereIn: selectors.toList())
          .snapshots(),
      db
          .collection('notifications')
          .where('recipientEmail', isEqualTo: email.trim().toLowerCase())
          .snapshots(),
      db
          .collection('notification_states')
          .doc(uid)
          .collection('items')
          .snapshots(),
    ];
    final latest = <int, QuerySnapshot<Map<String, dynamic>>>{};
    final subscriptions = <StreamSubscription>[];
    late StreamController<List<InboxNotification>> controller;
    controller =
        StreamController<List<InboxNotification>>.broadcast(onListen: () {
      latest.clear();
      for (var index = 0; index < sources.length; index++) {
        final key = index;
        subscriptions.add(sources[index].listen((snapshot) {
          latest[key] = snapshot;
          if (latest.length != sources.length) return;
          final records = <String, Map<String, dynamic>>{};
          for (final source in [0, 1]) {
            for (final doc in latest[source]!.docs) {
              records[doc.id] = doc.data();
            }
          }
          final states = {
            for (final doc in latest[2]!.docs) doc.id: doc.data()
          };
          controller.add(visibleNotifications(records, states));
        }, onError: controller.addError));
      }
    }, onCancel: () {
      for (final subscription in subscriptions) {
        subscription.cancel();
      }
      subscriptions.clear();
    });
    return controller.stream;
  }

  Future<void> markRead(List<InboxNotification> items) =>
      _save(items, dismiss: false);
  Future<void> clear(List<InboxNotification> items) =>
      _save(items, dismiss: true);
  Future<void> _save(List<InboxNotification> items,
      {required bool dismiss}) async {
    final unique = {for (final item in items) item.id: item};
    final ids = unique.keys.toList();
    final states =
        db.collection('notification_states').doc(uid).collection('items');
    for (var start = 0; start < ids.length; start += 400) {
      final batch = db.batch();
      for (final id in ids.skip(start).take(400)) {
        batch.set(
            states.doc(id),
            {
              'read': true,
              if (dismiss) 'dismissed': true,
              'updatedAt': FieldValue.serverTimestamp()
            },
            SetOptions(merge: true));
      }
      await batch.commit();
    }
  }
}
