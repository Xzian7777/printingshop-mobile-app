import 'loyalty_api.dart';
import 'dart:async';
import 'profile_directory.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'local_db_service.dart';
import 'dart:convert';

class OrderRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocalDbService _localDb = LocalDbService.instance;

  Stream<List<ProfileRecord>> watchOrders(Query query,
      {required bool includeLegacy}) {
    StreamSubscription? subscription;
    Timer? timer;
    String? revision;
    final current = <String, ProfileRecord>{};
    final legacy = <String, ProfileRecord>{};
    late StreamController<List<ProfileRecord>> controller;
    void emit() {
      if (controller.hasListener)
        controller.add({...legacy, ...current}.values.toList());
    }

    Future<void> refreshLegacy() async {
      try {
        final result = await LoyaltyApi.call(
            '/api/orders/history${revision == null ? '' : '?revision=$revision'}');
        if (!controller.hasListener || result['notModified'] == true) return;
        revision = result['revision'] as String?;
        legacy.clear();
        for (final value in result['orders'] as List) {
          final data = Map<String, dynamic>.from(value as Map);
          if (data['ownershipReviewRequired'] == true)
            legacy['${data['id']}'] = ProfileRecord('${data['id']}', data);
        }
        emit();
        if (legacy.isEmpty) timer?.cancel();
      } catch (_) {
        // Canonical owner-filtered live orders remain available during a server outage.
      }
    }

    controller = StreamController<List<ProfileRecord>>.broadcast(onListen: () {
      subscription = query.snapshots().listen((snapshot) {
        current.clear();
        for (final doc in snapshot.docs) {
          current[doc.id] = ProfileRecord(
              doc.id, Map<String, dynamic>.from(doc.data() as Map));
        }
        emit();
      }, onError: controller.addError);
      if (includeLegacy) {
        timer =
            Timer.periodic(const Duration(seconds: 30), (_) => refreshLegacy());
        refreshLegacy();
      }
    }, onCancel: () {
      subscription?.cancel();
      subscription = null;
      timer?.cancel();
    });
    return controller.stream;
  }

  CollectionReference get _ordersRef => _firestore
      .collection('artifacts')
      .doc('printcraft-pro')
      .collection('public')
      .doc('data')
      .collection('orders');

  // Check kung may Internet Connection
  Future<bool> isOnline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return !connectivityResult.contains(ConnectivityResult.none);
  }

  // 1. HYBRID FETCH: Maglo-load agad mula sa Local DB, tapos ico-connect sa Cloud
  Future<List<Map<String, dynamic>>> getOrdersHybrid(String userEmail) async {
    // Load agad mula sa Local Database
    List<Map<String, dynamic>> localData =
        await _localDb.getLocalOrders(userEmail);

    // Sync sa Cloud sa Background kapag online
    if (await isOnline()) {
      try {
        final query = _ordersRef
            .where('customerId',
                isEqualTo: FirebaseAuth.instance.currentUser?.uid ?? '')
            .orderBy('createdAt', descending: true)
            .limit(20);

        final snapshot = await query.get();
        for (var doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          await _localDb.insertOrUpdateOrder(data, isSynced: true);
        }

        // I-re-fetch ang updated local list
        localData = await _localDb.getLocalOrders(userEmail);
      } catch (e) {
        print("Cloud Sync Error (Using Local DB): $e");
      }
    }

    return localData;
  }

  // 2. AUTOMATIC SYNC NG OFFLINE QUEUED ORDERS
  Future<void> syncOfflineOrders() async {
    if (!await isOnline()) return;

    final unsynced = await _localDb.getUnsyncedOrders();
    for (var order in unsynced) {
      try {
        final payload = order['payload'] is String
            ? Map<String, dynamic>.from(jsonDecode(order['payload'] as String))
            : <String, dynamic>{};
        final complete = <String, dynamic>{
          'id': order['id'],
          'customer': order['customer'],
          'email': order['email'],
          'service': order['service'],
          'quantity': order['quantity'],
          'total': order['total'],
          'status': order['status'],
          'payment': order['payment'],
          'file': order['file'],
          'fileUrl': order['fileUrl'],
          'createdAt': FieldValue.serverTimestamp(),
          ...payload,
        };
        final user = FirebaseAuth.instance.currentUser;
        if (user == null ||
            order['email'].toString().toLowerCase() !=
                user.email?.toLowerCase()) continue;
        complete.remove('createdAt');
        complete['submissionId'] ??= 'legacy_queue_${order['id']}';
        final result = await LoyaltyApi.call('/api/orders',
            method: 'POST', data: complete);
        final saved = Map<String, dynamic>.from(result['order'] as Map);
        await _localDb.confirmQueuedOrder(order['id'], saved);
      } catch (e) {
        print("Failed to sync offline order ${order['id']}: $e");
      }
    }
  }
}
