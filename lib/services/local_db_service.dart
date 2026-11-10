import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

class LocalDbService {
  static final LocalDbService instance = LocalDbService._init();
  static Database? _database;

  LocalDbService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('printcraft_local.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2)
          await db.execute('ALTER TABLE local_orders ADD COLUMN payload TEXT');
        if (oldVersion < 4) {
          await db.execute('CREATE TABLE IF NOT EXISTS loyalty_pending (uid TEXT PRIMARY KEY, payload TEXT NOT NULL)');
        }
        if (oldVersion < 3) {
          await db.execute(
              'CREATE TABLE IF NOT EXISTS pos_drafts (cashier TEXT PRIMARY KEY, payload TEXT NOT NULL)');
        }
      },
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('CREATE TABLE loyalty_pending (uid TEXT PRIMARY KEY, payload TEXT NOT NULL)');
    await db.execute(
        'CREATE TABLE pos_drafts (cashier TEXT PRIMARY KEY, payload TEXT NOT NULL)');
    // Table para sa Cached Orders at Offline Queue
    await db.execute('''
      CREATE TABLE local_orders (
        id TEXT PRIMARY KEY,
        customer TEXT,
        email TEXT,
        service TEXT,
        quantity INTEGER,
        total REAL,
        status TEXT,
        payment TEXT,
        file TEXT,
        fileUrl TEXT,
        createdAt TEXT,
        payload TEXT,
        is_synced INTEGER DEFAULT 1
      )
    ''');
  }

  Future<Map<String, dynamic>?> getLoyaltyPending(String uid) async {
    final rows = await (await database).query('loyalty_pending', where: 'uid = ?', whereArgs: [uid]);
    return rows.isEmpty ? null : Map<String, dynamic>.from(jsonDecode(rows.first['payload'] as String));
  }
  Future<void> saveLoyaltyPending(String uid, Map<String, dynamic> payload) async {
    await (await database).insert('loyalty_pending', {'uid': uid, 'payload': jsonEncode(payload)}, conflictAlgorithm: ConflictAlgorithm.replace);
  }
  Future<void> clearLoyaltyPending(String uid) async {
    await (await database).delete('loyalty_pending', where: 'uid = ?', whereArgs: [uid]);
  }

  // Save or Update Order sa Local SQLite DB
  Future<Map<String, dynamic>?> getPosDraft(String cashier) async {
    final db = await database;
    final rows = await db
        .query('pos_drafts', where: 'cashier = ?', whereArgs: [cashier]);
    return rows.isEmpty
        ? null
        : Map<String, dynamic>.from(
            jsonDecode(rows.first['payload'] as String));
  }

  Future<void> savePosDraft(
      String cashier, Map<String, dynamic> payload) async {
    final db = await database;
    await db.insert(
        'pos_drafts', {'cashier': cashier, 'payload': jsonEncode(payload)},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> clearPosDraft(String cashier) async {
    final db = await database;
    await db.delete('pos_drafts', where: 'cashier = ?', whereArgs: [cashier]);
  }

  // Save or Update Order sa Local SQLite DB
  Future<void> insertOrUpdateOrder(Map<String, dynamic> order,
      {bool isSynced = true}) async {
    final db = await instance.database;
    await db.insert(
      'local_orders',
      {
        'id': order['id'],
        'customer': order['customer'] ?? '',
        'email': order['email'] ?? '',
        'service': order['service'] ?? '',
        'quantity': order['quantity'] ?? 1,
        'total':
            (order['total'] is num) ? (order['total'] as num).toDouble() : 0.0,
        'status': order['status'] ?? 'Order Submitted',
        'payment': order['payment'] ?? 'GCash',
        'file': order['file'] ?? '',
        'fileUrl': order['fileUrl'] ?? '',
        'createdAt':
            order['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
        'is_synced': isSynced ? 1 : 0,
        'payload': jsonEncode(order, toEncodable: (value) {
          if (value is Timestamp)
            return value.toDate().toUtc().toIso8601String();
          if (value is FieldValue)
            return DateTime.now().toUtc().toIso8601String();
          return value.toString();
        }),
      },
      conflictAlgorithm:
          isSynced ? ConflictAlgorithm.replace : ConflictAlgorithm.abort,
    );
  }

  // Get Local Cached Orders (Instant Query)
  Future<List<Map<String, dynamic>>> getLocalOrders(String email) async {
    final db = await instance.database;
    final isAdm = email.toLowerCase().trim() == 'supernovaelectrodog@gmail.com';
    return await db.query(
      'local_orders',
      where: isAdm ? null : 'email = ?',
      whereArgs: isAdm ? null : [email],
      orderBy: 'createdAt DESC',
    );
  }

  // Get Pending Offline Orders (Hindi pa nase-send sa Cloud)
  Future<List<Map<String, dynamic>>> getUnsyncedOrders() async {
    final db = await instance.database;
    return await db
        .query('local_orders', where: 'is_synced = ?', whereArgs: [0]);
  }

  // Mark Order as Synced sa Cloud
  Future<void> markAsSynced(String id, String cloudFileUrl) async {
    final db = await instance.database;
    await db.update(
      'local_orders',
      {'is_synced': 1, 'fileUrl': cloudFileUrl},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
