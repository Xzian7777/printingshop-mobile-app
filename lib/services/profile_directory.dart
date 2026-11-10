import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileRecord {
  final String id;
  final Map<String, dynamic> _data;
  ProfileRecord(this.id, this._data);
  Map<String, dynamic> data() => _data;
}

Stream<List<ProfileRecord>> watchProducts() {
  final db = FirebaseFirestore.instance;
  final sources = [
    db
        .collection('artifacts')
        .doc('printcraft-pro')
        .collection('public')
        .doc('data')
        .collection('store_products'),
    db.collection('products')
  ];
  final latest = <int, QuerySnapshot<Map<String, dynamic>>>{};
  final subscriptions = <StreamSubscription>[];
  late StreamController<List<ProfileRecord>> controller;
  controller = StreamController(onListen: () {
    for (var index = 0; index < sources.length; index++) {
      final key = index;
      subscriptions.add(sources[index].snapshots().listen((snapshot) {
        latest[key] = snapshot;
        if (latest.length != sources.length) return;
        final records = <String, ProfileRecord>{};
        for (var source = 0; source < sources.length; source++) {
          for (final doc in latest[source]!.docs) {
            records[doc.id] = ProfileRecord(doc.id, doc.data());
          }
        }
        controller.add(records.values.toList());
      }, onError: controller.addError));
    }
  }, onCancel: () async {
    for (final sub in subscriptions) {
      await sub.cancel();
    }
  });
  return controller.stream;
}

/// Include existing mobile-only profiles without migrating or duplicating data.
Stream<List<ProfileRecord>> watchProfiles() {
  final latest = <String, QuerySnapshot<Map<String, dynamic>>>{};
  final subscriptions = <StreamSubscription>[];
  late StreamController<List<ProfileRecord>> controller;
  controller = StreamController(onListen: () {
    for (final name in ['users', 'customers']) {
      subscriptions.add(FirebaseFirestore.instance
          .collection(name)
          .snapshots()
          .listen((snapshot) {
        latest[name] = snapshot;
        if (latest.length != 2) return;
        final merged = <String, ProfileRecord>{};
        for (final source in ['users', 'customers']) {
          for (final doc in latest[source]!.docs) {
            final data = doc.data();
            final email = (data['email'] ?? '').toString().trim().toLowerCase();
            final key = email.isEmpty ? '$source/${doc.id}' : email;
            final archived = merged[key]?.data()['archived'] == true ||
                merged[key]?.data()['isArchived'] == true ||
                data['archived'] == true ||
                data['isArchived'] == true;
            merged[key] = ProfileRecord(doc.id, {
              ...?merged[key]?.data(),
              ...data,
              'archived': archived,
              'isArchived': archived
            });
          }
        }
        controller.add(merged.values.toList());
      }, onError: controller.addError));
    }
  }, onCancel: () async {
    for (final sub in subscriptions) {
      await sub.cancel();
    }
  });
  return controller.stream;
}
