import 'loyalty_api.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminRepository {
  final FirebaseFirestore db;
  AdminRepository({FirebaseFirestore? firestore})
      : db = firestore ?? FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get products =>
      db.collection('products');
  CollectionReference<Map<String, dynamic>> get legacyProducts => db
      .collection('artifacts')
      .doc('printcraft-pro')
      .collection('public')
      .doc('data')
      .collection('store_products');

  Future<List<DocumentReference<Map<String, dynamic>>>> refs(
      String type, String id, Map<String, dynamic> data) async {
    if (type == 'store_product' || type == 'product')
      return [products.doc(id), legacyProducts.doc(id)];
    if (type == 'sample_product' || type == 'sample')
      return [
        db.collection('sample_products').doc(id),
        db.collection('sample_works').doc(id)
      ];
    if (type == 'service') return [db.collection('services').doc(id)];
    if (type != 'user') throw ArgumentError('Unknown item type: $type');
    final found = <String, DocumentReference<Map<String, dynamic>>>{};
    final email = (data['email'] ?? '').toString().trim().toLowerCase();
    for (final collection in ['users', 'customers']) {
      final direct = db.collection(collection).doc(id);
      if ((await direct.get()).exists) found[direct.path] = direct;
      if (email.isNotEmpty) {
        for (final doc in (await db
                .collection(collection)
                .where('email', isEqualTo: email)
                .get())
            .docs) {
          found[doc.reference.path] = doc.reference;
        }
      }
    }
    // Maintain a web profile for mobile users without changing existing IDs.
    final webId = (data['customerId'] ?? data['id'] ?? id).toString();
    found.putIfAbsent(
        'customers/$webId', () => db.collection('customers').doc(webId));
    if (!found.values.any((r) => r.parent.id == 'users')) {
      final uid = (data['uid'] ?? id).toString();
      found['users/$uid'] = db.collection('users').doc(uid);
    }
    return found.values.toList();
  }

  Future<void> saveProduct(String id, Map<String, dynamic> data,
      {bool create = false}) async {
    await db.runTransaction((tx) async {
      var current = await tx.get(products.doc(id));
      if (!current.exists) current = await tx.get(legacyProducts.doc(id));
      if (!create && (!current.exists || current.data()?['archived'] == true))
        throw StateError(
            'Product is unavailable or archived. Refresh inventory.');
      final payload = {
        ...data,
        'id': id,
        'updatedAt': FieldValue.serverTimestamp()
      };
      final expectedStock = payload.remove('expectedStock');
      if (expectedStock != null && current.data()?['stock'] != expectedStock)
        throw StateError('Stock changed. Refresh inventory before saving.');
      final price = double.tryParse(
          '${payload['price'] ?? current.data()?['price'] ?? 0}');
      final stock =
          int.tryParse('${payload['stock'] ?? current.data()?['stock'] ?? 0}');
      if (price == null ||
          !price.isFinite ||
          price < 0 ||
          price > 5000000 ||
          stock == null ||
          stock < 0 ||
          stock > 100000 ||
          '${payload['name'] ?? current.data()?['name'] ?? ''}'.trim().isEmpty)
        throw StateError(
            'Provide a name, valid price, and stock from 0 to 100,000.');
      tx.set(products.doc(id), payload, SetOptions(merge: true));
      tx.set(legacyProducts.doc(id), payload, SetOptions(merge: true));
    });
  }

  Future<void> saveProfile(String id, Map<String, dynamic> data,
      {bool create = false}) async {
    final targets = await refs('user', id, data);
    if (create &&
        (await Future.wait(targets.map((r) => r.get()))).any((d) => d.exists))
      throw StateError('A customer with this email already exists.');
    final batch = db.batch();
    final name = data['fullName'] ?? data['full_name'] ?? data['name'];
    final payload = {
      ...data,
      if (name != null) ...{'fullName': name, 'full_name': name, 'name': name},
      'updatedAt': FieldValue.serverTimestamp()
    };
    for (final target in targets) {
      final safe = Map<String, dynamic>.from(payload);
      if (target.parent.id == 'users') {
        safe.remove('password');
        safe.remove('passwordHash');
      }
      batch.set(target, safe, SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> archive(
      String type, String id, Map<String, dynamic> data) async {
    final canonical =
        {'product': 'store_product', 'sample': 'sample_product'}[type] ?? type;
    final targets = await refs(canonical, id, data);
    await db.runTransaction((tx) async {
      final snapshots = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final target in targets) {
        snapshots.add(await tx.get(target));
      }
      final existing = snapshots.where((d) => d.exists).toList();
      if (existing.isEmpty || existing.first.data()?['archived'] == true)
        throw StateError('Item is missing or already archived.');
      final latest = {...data, ...?existing.first.data(), 'id': id};
      final archiveId = '${canonical}_$id';
      tx.set(db.collection('archives').doc(archiveId), {
        'id': archiveId,
        'originalId': id,
        'itemType': canonical,
        'data': latest,
        'source': 'mobile_admin',
        'originalPaths': targets.map((r) => r.path).toList(),
        'archivedAt': DateTime.now().toUtc().toIso8601String(),
      });
      for (final target in targets) {
        final safe = Map<String, dynamic>.from(latest);
        if (target.parent.id == 'users') {
          safe.remove('password');
          safe.remove('passwordHash');
        }
        tx.set(
            target,
            {
              ...safe,
              'archived': true,
              'isArchived': true,
              'archivedAt': FieldValue.serverTimestamp()
            },
            SetOptions(merge: true));
      }
    });
  }

  Future<void> finishArchive(
      String type, String id, String archiveId, Map<String, dynamic> fallback,
      {required bool restore}) async {
    final archiveRef = db.collection('archives').doc(archiveId);
    final archive = await archiveRef.get();
    final saved = archive.data();
    final data = saved?['data'] is Map
        ? Map<String, dynamic>.from(saved!['data'])
        : fallback;
    final targets = await refs(type, id, data);
    for (final path in (saved?['originalPaths'] as List? ?? [])) {
      final ref = db.doc(path.toString());
      if (!targets.any((r) => r.path == ref.path)) targets.add(ref);
    }
    await db.runTransaction((tx) async {
      final currentArchive = await tx.get(archiveRef);
      final current = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final ref in targets) {
        current.add(await tx.get(ref));
      }
      if (!currentArchive.exists &&
          !current.any((d) => d.data()?['archived'] == true))
        throw StateError('Item was already restored or deleted.');
      bool compatibleUser(DocumentSnapshot<Map<String, dynamic>> doc) =>
          restore &&
          type == 'user' &&
          (data['email'] ?? '').toString().isNotEmpty &&
          doc.data()?['email'] == data['email'];
      if (current.any((d) =>
          d.exists && d.data()?['archived'] != true && !compatibleUser(d)))
        throw StateError(
            'An active record already exists. Refresh before continuing.');
      final payload = {
        ...((currentArchive.data()?['data'] is Map)
            ? Map<String, dynamic>.from(currentArchive.data()!['data'])
            : data),
        'id': id,
        'archived': false,
        'isArchived': false
      };
      if (type == 'product' || type == 'store_product') {
        final candidates = current.where((d) => d.exists).toList()
          ..sort((a, b) => (a.reference.parent.id == 'products' ? 0 : 1)
              .compareTo(b.reference.parent.id == 'products' ? 0 : 1));
        if (candidates.isNotEmpty)
          payload.addAll({
            ...candidates.first.data()!,
            'id': id,
            'archived': false,
            'isArchived': false
          });
      }
      payload.remove('archivedAt');
      for (final ref in targets) {
        if (restore) {
          final before =
              current.firstWhere((d) => d.reference.path == ref.path);
          if (before.exists &&
              before.data()?['archived'] != true &&
              compatibleUser(before)) {
            tx.set(
                ref,
                {
                  'archived': false,
                  'isArchived': false,
                  'archivedAt': FieldValue.delete()
                },
                SetOptions(merge: true));
          } else {
            final safe = Map<String, dynamic>.from(payload);
            if (type == 'user') {
              for (final field in ['points', 'loyaltyPoints', 'loyaltyUid']) {
                if (before.exists) {
                  if (before.data()!.containsKey(field)) {
                    safe[field] = before.data()![field];
                  } else {
                    safe.remove(field);
                  }
                } else if (field != 'loyaltyUid') {
                  safe[field] = 0;
                }
              }
            }
            if (ref.parent.id == 'users') {
              safe.remove('password');
              safe.remove('passwordHash');
            }
            tx.set(ref, safe);
          }
        } else {
          tx.delete(ref);
        }
      }
      tx.delete(archiveRef);
    });
  }

  Future<void> tapCard(String cardUid) async {
    await LoyaltyApi.call('/api/rfid/tap',
        method: 'POST', data: {'rfidCardUid': cardUid});
  }
}
