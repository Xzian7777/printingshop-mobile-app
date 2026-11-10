import 'loyalty_api.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'admin_repository.dart';
import 'local_db_service.dart';

class PosRepository {
  late final AdminRepository _repo = AdminRepository();
  FirebaseFirestore get db => _repo.db;
  String get cashier => FirebaseAuth.instance.currentUser?.uid ?? '';

  Future<Map<String, dynamic>?> getDraft() =>
      LocalDbService.instance.getPosDraft(cashier);
  Future<void> saveDraft(Map<String, dynamic> payload) =>
      LocalDbService.instance.savePosDraft(cashier, payload);
  Future<void> clearDraft() => LocalDbService.instance.clearPosDraft(cashier);

  Future<List<Map<String, dynamic>>> catalog() async {
    const online = GetOptions(source: Source.server);
    final sources = await Future.wait([
      _repo.legacyProducts.get(online),
      _repo.products.get(online),
      db.collection('services').get(online),
    ]);
    final items = <String, Map<String, dynamic>>{};
    for (var index = 0; index < sources.length; index++) {
      final kind = index == 2 ? 'service' : 'product';
      for (final doc in sources[index].docs) {
        items['$kind/${doc.id}'] = {
          ...doc.data(),
          'id': doc.id,
          'kind': kind,
          'price': index == 2
              ? doc.data()['basePrice'] ?? 0
              : doc.data()['price'] ?? 0
        };
      }
    }
    return items.values
        .where((x) => x['archived'] != true && x['isArchived'] != true)
        .toList();
  }

  Future<List<Map<String, dynamic>>> history() async {
    final result = await db
        .collection('pos_sales')
        .orderBy('recordedAt', descending: true)
        .limit(20)
        .get(const GetOptions(source: Source.server));
    return result.docs.map((doc) => doc.data()).toList();
  }

  Future<Map<String, dynamic>> complete(Map<String, dynamic> request) async {
    if (request['actorUid'] != cashier || cashier.isEmpty) {
      throw const FormatException('Sign in with the cashier account that started this sale.');
    }
    final result = await LoyaltyApi.call('/api/pos/sales', method: 'POST', data: request);
    return Map<String, dynamic>.from(result['sale']);
  }
}
