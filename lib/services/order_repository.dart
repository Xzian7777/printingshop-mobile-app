import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'local_db_service.dart';

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
    List<Map<String, dynamic>> localData = await _localDb.getLocalOrders(userEmail);

    // Sync sa Cloud sa Background kapag online
    if (await isOnline()) {
      try {
        Query query = _ordersRef.orderBy('createdAt', descending: true).limit(20); // PAGINATION LIMIT
        if (!userEmail.toLowerCase().contains('admin')) {
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
        await _ordersRef.doc(order['id']).set({
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
        });

        await _localDb.markAsSynced(order['id'], order['fileUrl']);
      } catch (e) {
        print("Failed to sync offline order ${order['id']}: $e");
      }
    }
  }
}