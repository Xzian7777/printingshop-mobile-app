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

/// Group verified UID profiles and expose legacy records for read-only review.
List<ProfileRecord> mergeProfiles(
    List<ProfileRecord> users, List<ProfileRecord> customers) {
  final canonical = {
    for (final record in users)
      if (record.data()['uid'] == record.id ||
          record.data()['loyaltyUid'] == record.id)
        record.id: record
  };
  final emailUids = <String, Set<String>>{};
  for (final record in canonical.values) {
    final email = '${record.data()['email'] ?? ''}'.trim().toLowerCase();
    emailUids.putIfAbsent(email, () => {}).add(record.id);
  }
  final groups = <String, List<ProfileRecord>>{};
  final emailBindings = <String, Set<String>>{};
  for (final record in [...users, ...customers]) {
    final data = record.data();
    final email = '${data['email'] ?? ''}'.trim().toLowerCase();
    final candidates = emailUids[email] ?? {};
    final uid = data['uid'] ??
        data['loyaltyUid'] ??
        (candidates.length == 1 ? candidates.single : null);
    final bindings = emailBindings.putIfAbsent(email, () => {});
    for (final value in [uid, data['loyaltyUid']]) {
      if (value != null && '$value'.isNotEmpty) bindings.add('$value');
    }
    final key = '${uid ?? (email.isEmpty ? record.id : email)}';
    groups.putIfAbsent(key, () => []).add(record);
  }
  return [
    for (final entry in groups.entries)
      _mergeProfileGroup(
          entry.key,
          entry.value,
          canonical[entry.key],
          customers,
          entry.value.any((record) =>
              (emailBindings['${record.data()['email'] ?? ''}'
                          .trim()
                          .toLowerCase()]
                      ?.length ??
                  0) >
              1))
  ];
}

ProfileRecord _mergeProfileGroup(
    String uid,
    List<ProfileRecord> members,
    ProfileRecord? primary,
    List<ProfileRecord> customers,
    bool conflictingEmail) {
  final mirrors = members.where(customers.contains).toList();
  final cards = {
    for (final member in members)
      if ('${member.data()['rfidUid'] ?? ''}'.isNotEmpty)
        '${member.data()['rfidUid']}'
  };
  final legacyUsers = primary != null &&
      members.any((record) =>
          !customers.contains(record) &&
          record.id != uid &&
          record.data()['uid'] != uid);
  final customerId = primary?.data()['customerId'];
  final conflictingId = mirrors.length == 1 &&
      customerId != null &&
      '$customerId' != mirrors.first.id;
  final review = mirrors.length > 1 ||
      cards.length > 1 ||
      legacyUsers ||
      conflictingId ||
      conflictingEmail;
  final data = <String, dynamic>{
    for (final member in members) ...member.data(),
    ...?primary?.data()
  };
  if (primary != null) {
    final profile = primary.data();
    final name = profile['fullName'] ?? profile['full_name'] ?? profile['name'];
    if (name != null)
      data.addAll({'fullName': name, 'full_name': name, 'name': name});
  }
  final archived = members.any((record) =>
      record.data()['archived'] == true || record.data()['isArchived'] == true);
  return ProfileRecord(
      primary != null && review
          ? primary.id
          : (mirrors.isNotEmpty ? mirrors.first.id : members.first.id),
      {
        ...data,
        if (primary != null) ...{
          'uid': primary.id,
          'role': primary.data()['role'] ?? 'customer'
        },
        if (review) 'rfidUid': primary?.data()['rfidUid'] ?? '',
        if ('${primary?.data()['physicalRfidUid'] ?? ''}'.isNotEmpty)
          'rfidUid': primary!.data()['physicalRfidUid'],
        'legacyCustomerIds': mirrors.map((record) => record.id).toList()
          ..sort(),
        'profileResolution': review ? 'needs_review' : 'resolved',
        'rfidReviewRequired': review,
        'archived': archived,
        'isArchived': archived,
      });
}

Stream<List<ProfileRecord>> watchProfiles() {
  final latest = <String, List<ProfileRecord>>{};
  final subscriptions = <StreamSubscription>[];
  late StreamController<List<ProfileRecord>> controller;
  controller = StreamController(onListen: () {
    for (final name in ['users', 'customers']) {
      subscriptions.add(FirebaseFirestore.instance
          .collection(name)
          .snapshots()
          .listen((snapshot) {
        latest[name] = [
          for (final doc in snapshot.docs) ProfileRecord(doc.id, doc.data())
        ];
        if (latest.length == 2)
          controller.add(mergeProfiles(latest['users']!, latest['customers']!));
      }, onError: controller.addError));
    }
  }, onCancel: () async {
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
  });
  return controller.stream;
}
