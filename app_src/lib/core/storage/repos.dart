import 'package:csv/csv.dart';
import 'package:sqflite/sqflite.dart';
import 'db.dart';

class Repos {
  static Future<Database> _db() => AppDb.instance();

  static List<String> _splitLocations(String s) {
    return s.split('|').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  static int _preferredIndex(String preferredLocations, String locationCode) {
    final list = _splitLocations(preferredLocations.toUpperCase());
    final idx = list.indexOf(locationCode.toUpperCase());
    return idx < 0 ? 999999 : idx;
  }

  static Future<String?> resolveLocationBarcode(String barcode) async {
    final db = await _db();
    final rows = await db.query(
      'location_barcodes',
      columns: ['locationCode'],
      where: 'barcode = ?',
      whereArgs: [barcode.trim().toUpperCase()],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['locationCode'] as String;
  }

  static Future<String?> findBestOpenTask({
    required String productBarcode,
    required String locationCode,
  }) async {
    final db = await _db();

    final rows = await db.query(
      'pick_tasks',
      where: 'status = ? AND barcode = ?',
      whereArgs: ['OPEN', productBarcode.trim().toUpperCase()],
    );

    if (rows.isEmpty) return null;

    final candidates = rows.where((r) {
      final pref = (r['preferredLocations'] as String?) ?? '';
      final list = _splitLocations(pref.toUpperCase());
      return list.contains(locationCode.toUpperCase());
    }).toList();

    if (candidates.isEmpty) return null;

    candidates.sort((a, b) {
      final prefA = (a['preferredLocations'] as String?) ?? '';
      final prefB = (b['preferredLocations'] as String?) ?? '';
      final idxA = _preferredIndex(prefA, locationCode);
      final idxB = _preferredIndex(prefB, locationCode);
      if (idxA != idxB) return idxA.compareTo(idxB);

      final reqA = (a['reqQty'] as int?) ?? 0;
      final pickedA = (a['pickedQty'] as int?) ?? 0;
      final remA = (reqA - pickedA).clamp(0, 999999);

      final reqB = (b['reqQty'] as int?) ?? 0;
      final pickedB = (b['pickedQty'] as int?) ?? 0;
      final remB = (reqB - pickedB).clamp(0, 999999);

      return remA.compareTo(remB);
    });

    return candidates.first['taskId'] as String;
  }

  static Future<void> savePick({
    required String eventId,
    required String taskId,
    required String locationCode,
    required String productBarcode,
    required int qty,
    required DateTime createdAt,
  }) async {
    final db = await _db();

    await db.transaction((txn) async {
      await txn.insert('pick_events', {
        'eventId': eventId,
        'taskId': taskId,
        'locationCode': locationCode,
        'productBarcode': productBarcode.trim().toUpperCase(),
        'qty': qty,
        'createdAt': createdAt.toIso8601String(),
        'synced': 0,
      });

      await txn.rawUpdate('''
        UPDATE pick_tasks
        SET pickedQty = pickedQty + ?
        WHERE taskId = ?
      ''', [qty, taskId]);

      final updated = await txn.query(
        'pick_tasks',
        columns: ['reqQty', 'pickedQty'],
        where: 'taskId = ?',
        whereArgs: [taskId],
        limit: 1,
      );

      if (updated.isNotEmpty) {
        final req = (updated.first['reqQty'] as int?) ?? 0;
        final picked = (updated.first['pickedQty'] as int?) ?? 0;
        if (picked >= req && req > 0) {
          await txn.update(
            'pick_tasks',
            {'status': 'DONE'},
            where: 'taskId = ?',
            whereArgs: [taskId],
          );
        }
      }
    });
  }

  static Future<void> importProductsCsv(String csvText) async {
    final db = await _db();
    final rows = const CsvToListConverter(eol: '\n').convert(csvText);
    if (rows.length <= 1) return;

    await db.transaction((txn) async {
      for (int i = 1; i < rows.length; i++) {
        final r = rows[i];
        await txn.insert(
          'products',
          {
            'barcode': r[0].toString().trim().toUpperCase(),
            'sku': r[1].toString().trim(),
            'name': r[2].toString().trim(),
            'uom': r[3].toString().trim(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  static Future<void> importLocationBarcodesCsv(String csvText) async {
    final db = await _db();
    final rows = const CsvToListConverter(eol: '\n').convert(csvText);
    if (rows.length <= 1) return;

    await db.transaction((txn) async {
      for (int i = 1; i < rows.length; i++) {
        final r = rows[i];
        final barcode = r[0].toString().trim().toUpperCase();
        final loc = r[1].toString().trim();
        await txn.insert(
          'location_barcodes',
          {'barcode': barcode, 'locationCode': loc},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  static Future<void> importPickTasksCsv(String csvText) async {
    final db = await _db();
    final rows = const CsvToListConverter(eol: '\n').convert(csvText);
    if (rows.length <= 1) return;

    await db.transaction((txn) async {
      for (int i = 1; i < rows.length; i++) {
        final r = rows[i];
        await txn.insert(
          'pick_tasks',
          {
            'taskId': r[0].toString().trim(),
            'batchId': r[1].toString().trim(),
            'barcode': r[2].toString().trim().toUpperCase(),
            'sku': r[3].toString().trim(),
            'reqQty': int.tryParse(r[4].toString()) ?? 0,
            'pickedQty': 0,
            'preferredLocations': r[5].toString().trim(),
            'status': 'OPEN',
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  static Future<String> getQuickSummary() async {
    final db = await _db();
    final open = Sqflite.firstIntValue(
          await db.rawQuery("SELECT COUNT(*) FROM pick_tasks WHERE status='OPEN'"),
        ) ??
        0;
    final done = Sqflite.firstIntValue(
          await db.rawQuery("SELECT COUNT(*) FROM pick_tasks WHERE status='DONE'"),
        ) ??
        0;
    final events = Sqflite.firstIntValue(
          await db.rawQuery("SELECT COUNT(*) FROM pick_events"),
        ) ??
        0;

    return 'Tasks: OPEN=$open, DONE=$done\nPick events recorded: $events';
  }
}
