import 'app_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'local_db_service.dart';
import 'order_reference.dart';
import 'dart:convert';

class OrderRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocalDbService _localDb = LocalDbService.instance;

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
        Query query = _ordersRef
            .orderBy('createdAt', descending: true)
            .limit(20); // PAGINATION LIMIT
        if (userEmail.toLowerCase().trim() != 'supernovaelectrodog@gmail.com') {
          query = query.where('email', isEqualTo: userEmail);
        }

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
        final ref = _ordersRef.doc(order['id']);
        await _firestore.runTransaction((tx) async {
          final existing = await tx.get(ref);
          if (existing.exists) {
            if (!isSameOrderSubmission(
                existing.data() as Map<String, dynamic>, complete)) {
              throw StateError('Order ID conflict.');
            }
            return; // A timed-out request may already have created this order.
          }
          final serviceId = complete['serviceId']?.toString();
          if (serviceId != null && serviceId.isNotEmpty) {
            final service =
                await tx.get(_firestore.collection('services').doc(serviceId));
            if (!service.exists ||
                service.data()?['archived'] == true ||
                (service.data()?['updatedAt'] ?? '').toString() !=
                    complete['serviceVersion'])
              throw StateError(
                  'Queued service changed; review this order before resubmitting.');
          }
          if (complete['payment'] == 'GCash Online' &&
              complete['merchantAccountNumber'] != null) {
            final merchant = await tx
                .get(_firestore.collection('settings').doc('gcash_config'));
            if (merchant.data()?['isActive'] == false ||
                merchant.data()?['accountNumber'] !=
                    complete['merchantAccountNumber'])
              throw StateError(
                  'Queued GCash details changed; review payment before resubmitting.');
          }
          tx.set(ref, complete);
          addNewOrderNotification(tx, _firestore, ref.id, complete);
        });

        await _localDb.markAsSynced(order['id'], order['fileUrl']);
      } catch (e) {
        print("Failed to sync offline order ${order['id']}: $e");
      }
    }
  }
}
