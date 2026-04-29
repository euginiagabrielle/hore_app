import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDbHelper {
  static final LocalDbHelper instance = LocalDbHelper._init();
  static Database? _database;

  LocalDbHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('sales_offline_orders.db');
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
    // Main order table
    await db.execute('''
      CREATE TABLE draft_orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER,
        customer_name TEXT,
        customer_phone TEXT,
        employee_id INTEGER NOT NULL,
        employee_name TEXT NOT NULL,
        total_price REAL NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    // Detail order table
    await db.execute('''
      CREATE TABLE draft_order_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        draft_order_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        original_price REAL NOT NULL,
        price REAL NOT NULL,
        discount_amount REAL NOT NULL DEFAULT 0.0
      )
    ''');
  }

  // Save order to local
  Future<int> saveDraftOrder({
    required int? customerId,
    required String? customerName,
    required int employeeId,
    required String employeeName,
    required double totalPrice,
    required List<Map<String, dynamic>> items,
  }) async {
    final db = await database;
    return await db.transaction((txn) async {
      final orderId = await txn.insert('draft_orders', {
        'customer_id': customerId,
        'customer_name': customerName,
        'employee_id': employeeId,
        'employee_name': employeeName,
        'total_price': totalPrice,
        'is_synced': 0,
        'created_at': DateTime.now().toIso8601String(),
      });

      for (var item in items) {
        await txn.insert('draft_order_items', {
          'draft_order_id': orderId,
          'product_id': item['product']['product_id'],
          'product_name': item['product']['product_name'],
          'quantity': item['quantity'],
          'original_price': item['original_price'],
          'price': item['price'],
          'discount_amount': item['discount_amount'],
        });
      }
      return orderId;
    });
  }

  Future<List<Map<String, dynamic>>> getUnsyncedOrders() async {
    final db = await instance.database;
    return await db.query('draft_orders', where: 'is_synced = ?', whereArgs: [0]);
  }

  Future<List<Map<String, dynamic>>> getOrderItems(int draftOrderId) async {
    final db = await instance.database;
    return await db.query('draft_order_items', where: 'draft_order_id = ?', whereArgs: [draftOrderId]);
  }

  Future<void> markAsSynced(int draftOrderId) async {
    final db = await instance.database;
    await db.update(
      'draft_orders',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [draftOrderId],    
    );
  }
}