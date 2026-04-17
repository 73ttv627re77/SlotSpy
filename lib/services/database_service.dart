import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/slot.dart';
import '../models/watch.dart';

class DatabaseService {
  static Database? _db;
  static const String _dbName = 'slotspy.db';
  static const int _dbVersion = 1;

  Future<Database> get db async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE slot_cache (
        id TEXT PRIMARY KEY,
        session_series_id TEXT,
        start_date TEXT,
        end_date TEXT,
        remaining_uses INTEGER,
        maximum_uses INTEGER,
        facility_use_url TEXT,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE session_series_cache (
        id TEXT PRIMARY KEY,
        data TEXT,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE session_types_cache (
        gym_id TEXT PRIMARY KEY,
        gym_name TEXT,
        session_type_names TEXT,
        all_data TEXT,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE watches (
        id TEXT PRIMARY KEY,
        data TEXT,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE last_alerted (
        watch_slot_key TEXT PRIMARY KEY,
        alerted_at TEXT
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_slot_start ON slot_cache(start_date)
    ''');

    await db.execute('''
      CREATE INDEX idx_session_series_id ON slot_cache(session_series_id)
    ''');
  }

  // Slot cache methods
  Future<void> upsertSlot(Slot slot) async {
    final database = await db;
    await database.insert(
      'slot_cache',
      {
        'id': slot.id,
        'session_series_id': slot.sessionSeriesId,
        'start_date': slot.startDate.toIso8601String(),
        'end_date': slot.endDate.toIso8601String(),
        'remaining_uses': slot.remainingUses,
        'maximum_uses': slot.maximumUses,
        'facility_use_url': slot.facilityUseUrl,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertSlots(List<Slot> slots) async {
    final database = await db;
    final batch = database.batch();
    for (final slot in slots) {
      batch.insert(
        'slot_cache',
        {
          'id': slot.id,
          'session_series_id': slot.sessionSeriesId,
          'start_date': slot.startDate.toIso8601String(),
          'end_date': slot.endDate.toIso8601String(),
          'remaining_uses': slot.remainingUses,
          'maximum_uses': slot.maximumUses,
          'facility_use_url': slot.facilityUseUrl,
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<int?> getSlotRemainingUses(String slotId) async {
    final database = await db;
    final results = await database.query(
      'slot_cache',
      columns: ['remaining_uses'],
      where: 'id = ?',
      whereArgs: [slotId],
    );
    if (results.isEmpty) return null;
    return results.first['remaining_uses'] as int;
  }

  Future<List<Slot>> getAvailableSlots() async {
    final database = await db;
    final results = await database.query(
      'slot_cache',
      where: 'remaining_uses >= 1',
      orderBy: 'start_date ASC',
    );
    return results.map((row) => _slotFromRow(row)).toList();
  }

  Future<List<Slot>> getAvailableSlotsForGym(String gymId) async {
    final database = await db;
    final results = await database.query(
      'slot_cache',
      where: 'remaining_uses >= 1 AND facility_use_url LIKE ?',
      whereArgs: ['%$gymId%'],
      orderBy: 'start_date ASC',
    );
    return results.map((row) => _slotFromRow(row)).toList();
  }

  Slot _slotFromRow(Map<String, dynamic> row) {
    return Slot(
      id: row['id'] as String,
      sessionSeriesId: row['session_series_id'] as String,
      startDate: DateTime.parse(row['start_date'] as String),
      endDate: DateTime.parse(row['end_date'] as String),
      duration: Duration(
        milliseconds: DateTime.parse(row['end_date'] as String)
            .difference(DateTime.parse(row['start_date'] as String))
            .inMilliseconds,
      ),
      remainingUses: row['remaining_uses'] as int,
      maximumUses: row['maximum_uses'] as int,
      facilityUseUrl: row['facility_use_url'] as String,
    );
  }

  // Session series cache
  Future<void> cacheSessionSeries(String id, Map<String, dynamic> data) async {
    final database = await db;
    await database.insert(
      'session_series_cache',
      {
        'id': id,
        'data': jsonEncode(data),
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> cacheSessionSeriesList(
      List<Map<String, dynamic>> items) async {
    final database = await db;
    final batch = database.batch();
    for (final item in items) {
      final id = item['data']?['@id'] ?? item['id'] ?? '';
      if (id.isNotEmpty) {
        batch.insert(
          'session_series_cache',
          {
            'id': id,
            'data': jsonEncode(item['data'] ?? item),
            'updated_at': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
    await batch.commit(noResult: true);
  }

  Future<Map<String, dynamic>?> getSessionSeries(String id) async {
    final database = await db;
    final results = await database.query(
      'session_series_cache',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (results.isEmpty) return null;
    return jsonDecode(results.first['data'] as String);
  }

  Future<List<Map<String, dynamic>>> getAllSessionSeries() async {
    final database = await db;
    final results = await database.query('session_series_cache');
    return results
        .map((row) => jsonDecode(row['data'] as String) as Map<String, dynamic>)
        .toList();
  }

  /// Save all session types for a specific gym, keyed by gym_id.
  /// sessionTypeNames: distinct session type display names (e.g. ["Gym 14-15 Yrs", "PT Taster Session"])
  /// allData: full JSON array of all session-series items for this gym
  Future<void> saveSessionTypesForGym({
    required String gymId,
    required String gymName,
    required List<String> sessionTypeNames,
    required List<Map<String, dynamic>> allData,
  }) async {
    final database = await db;
    await database.insert(
      'session_types_cache',
      {
        'gym_id': gymId,
        'gym_name': gymName,
        'session_type_names': jsonEncode(sessionTypeNames),
        'all_data': jsonEncode(allData),
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get cached session type names for a gym. Returns null if not cached.
  Future<List<String>?> getSessionTypeNamesForGym(String gymId) async {
    final database = await db;
    final results = await database.query(
      'session_types_cache',
      where: 'gym_id = ?',
      whereArgs: [gymId],
    );
    if (results.isEmpty) return null;
    final names = jsonDecode(results.first['session_type_names'] as String) as List;
    return names.cast<String>();
  }

  /// Get all cached session types for a gym (full data, for future use).
  Future<List<Map<String, dynamic>>?> getAllDataForGym(String gymId) async {
    final database = await db;
    final results = await database.query(
      'session_types_cache',
      where: 'gym_id = ?',
      whereArgs: [gymId],
    );
    if (results.isEmpty) return null;
    final data = jsonDecode(results.first['all_data'] as String) as List;
    return data.cast<Map<String, dynamic>>();
  }

  /// Check if session_types_cache has any data.
  Future<bool> hasSessionTypesCache() async {
    final database = await db;
    final results = await database.query('session_types_cache', limit: 1);
    return results.isNotEmpty;
  }

  // Watch methods
  Future<void> saveWatch(Watch watch) async {
    final database = await db;
    await database.insert(
      'watches',
      {
        'id': watch.id,
        'data': jsonEncode(watch.toJson()),
        'created_at': watch.createdAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteWatch(String id) async {
    final database = await db;
    await database.delete('watches', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Watch>> getAllWatches() async {
    final database = await db;
    final results = await database.query('watches', orderBy: 'created_at DESC');
    return results.map((row) {
      final data = jsonDecode(row['data'] as String) as Map<String, dynamic>;
      return Watch.fromJson(data);
    }).toList();
  }

  Future<void> clearAllWatches() async {
    final database = await db;
    await database.delete('watches');
  }

  // Alert debounce
  Future<bool> shouldAlert(String watchId, String slotId, {int debounceMinutes = 30}) async {
    final database = await db;
    final key = '${watchId}_$slotId';
    final results = await database.query(
      'last_alerted',
      where: 'watch_slot_key = ?',
      whereArgs: [key],
    );
    if (results.isEmpty) return true;
    final alertedAt = DateTime.parse(results.first['alerted_at'] as String);
    return DateTime.now().difference(alertedAt).inMinutes >= debounceMinutes;
  }

  Future<void> recordAlert(String watchId, String slotId) async {
    final database = await db;
    final key = '${watchId}_$slotId';
    await database.insert(
      'last_alerted',
      {
        'watch_slot_key': key,
        'alerted_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearOldAlerts({int olderThanDays = 7}) async {
    final database = await db;
    final cutoff = DateTime.now().subtract(Duration(days: olderThanDays));
    await database.delete(
      'last_alerted',
      where: 'alerted_at < ?',
      whereArgs: [cutoff.toIso8601String()],
    );
  }
}
