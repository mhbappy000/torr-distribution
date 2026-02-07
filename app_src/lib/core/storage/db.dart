import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class AppDb {
  static Database? _db;

  static Future<Database> instance() async {
    if (_db != null) return _db!;

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'torr_distribution.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await _createSchema(db);
      },
    );

    return _db!;
  }

  static Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS products (
        barcode TEXT PRIMARY KEY,
        sku TEXT,
        name TEXT,
        uom TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS location_barcodes (
        barcode TEXT PRIMARY KEY,
        locationCode TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS pick_tasks (
        taskId TEXT PRIMARY KEY,
        batchId TEXT,
        barcode TEXT,
        sku TEXT,
        reqQty INTEGER,
        pickedQty INTEGER DEFAULT 0,
        preferredLocations TEXT,
        status TEXT DEFAULT 'OPEN'
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS pick_events (
        eventId TEXT PRIMARY KEY,
        taskId TEXT NOT NULL,
        locationCode TEXT NOT NULL,
        productBarcode TEXT NOT NULL,
        qty INTEGER NOT NULL,
        createdAt TEXT NOT NULL,
        synced INTEGER DEFAULT 0
      );
    ''');

    await db.execute('CREATE INDEX IF NOT EXISTS idx_tasks_barcode ON pick_tasks(barcode);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_locbarcode ON location_barcodes(barcode);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_events_task ON pick_events(taskId);');
  }
}
