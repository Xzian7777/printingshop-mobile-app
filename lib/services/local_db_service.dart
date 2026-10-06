import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

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
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
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
        is_synced INTEGER DEFAULT 1
      )
    ''');
  }

  // Save or Update Order sa Local SQLite DB
  Future<void> insertOrUpdateOrder(Map<String, dynamic> order, {bool isSynced = true}) async {
    final db = await instance.database;
    await db.insert(
      'local_orders',
      {
        'id': order['id'],
        'customer': order['customer'] ?? '',
        'email': order['email'] ?? '',
        'service': order['service'] ?? '',
        'quantity': order['quantity'] ?? 1,
        'total': (order['total'] is num) ? (order['total'] as num).toDouble() : 0.0,
        'status': order['status'] ?? 'Order Submitted',
        'payment': order['payment'] ?? 'GCash',
        'file': order['file'] ?? '',
        'fileUrl': order['fileUrl'] ?? '',
        'createdAt': order['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
        'is_synced': isSynced ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
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
    return await db.query('local_orders', where: 'is_synced = ?', whereArgs: [0]);
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