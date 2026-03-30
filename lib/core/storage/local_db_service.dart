import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// SQLite database service providing offline queue management,
/// animal caching and form-schema caching for CattleShield 2.0.
class LocalDbService {
  static const String _dbName = 'cattleshield.db';
  static const int _dbVersion = 1;

  Database? _database;

  /// Returns the singleton database instance, creating it on first access.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // ---------------------------------------------------------------------------
  // Schema creation
  // ---------------------------------------------------------------------------

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE offline_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action TEXT NOT NULL,
        endpoint TEXT NOT NULL,
        payload TEXT,
        images TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        retry_count INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE cached_animals (
        id TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE cached_form_schemas (
        id TEXT PRIMARY KEY,
        schema TEXT NOT NULL,
        version TEXT,
        updated_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Reserved for future migrations.
  }

  // ---------------------------------------------------------------------------
  // Offline Queue
  // ---------------------------------------------------------------------------

  /// Adds a new entry to the offline queue.
  ///
  /// [action] describes the HTTP method (e.g. 'POST', 'PUT').
  /// [endpoint] is the API path.
  /// [payload] is a JSON-encodable map of body data.
  /// [images] is an optional list of local image file paths.
  Future<int> addToQueue({
    required String action,
    required String endpoint,
    Map<String, dynamic>? payload,
    List<String>? images,
  }) async {
    final db = await database;
    return db.insert('offline_queue', {
      'action': action,
      'endpoint': endpoint,
      'payload': payload != null ? jsonEncode(payload) : null,
      'images': images != null ? jsonEncode(images) : null,
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
      'retry_count': 0,
    });
  }

  /// Returns all queue items with the given [status] (default: `'pending'`),
  /// ordered by creation date (oldest first).
  Future<List<Map<String, dynamic>>> getPendingItems({
    String status = 'pending',
  }) async {
    final db = await database;
    return db.query(
      'offline_queue',
      where: 'status = ?',
      whereArgs: [status],
      orderBy: 'created_at ASC',
    );
  }

  /// Updates the [status] of a queue item and optionally increments its
  /// retry count.
  Future<int> updateStatus({
    required int id,
    required String status,
    bool incrementRetry = false,
  }) async {
    final db = await database;
    final Map<String, dynamic> values = {'status': status};

    if (incrementRetry) {
      // Use raw SQL to atomically increment.
      await db.rawUpdate(
        'UPDATE offline_queue SET status = ?, retry_count = retry_count + 1 WHERE id = ?',
        [status, id],
      );
      return 1;
    }

    return db.update(
      'offline_queue',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Permanently removes a queue item by [id].
  Future<int> deleteItem(int id) async {
    final db = await database;
    return db.delete(
      'offline_queue',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Deletes all completed or failed items from the queue.
  Future<int> clearCompletedItems() async {
    final db = await database;
    return db.delete(
      'offline_queue',
      where: 'status IN (?, ?)',
      whereArgs: ['completed', 'failed'],
    );
  }

  /// Returns the total count of pending items in the queue.
  Future<int> getPendingCount() async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) as count FROM offline_queue WHERE status = 'pending'",
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ---------------------------------------------------------------------------
  // Cached Animals
  // ---------------------------------------------------------------------------

  /// Inserts or replaces a cached animal record.
  ///
  /// [id] is the animal's unique identifier.
  /// [data] is the full JSON-serialisable animal map.
  /// [synced] indicates whether the record has been synced to the server.
  Future<int> cacheAnimal({
    required String id,
    required Map<String, dynamic> data,
    bool synced = false,
  }) async {
    final db = await database;
    return db.insert(
      'cached_animals',
      {
        'id': id,
        'data': jsonEncode(data),
        'synced': synced ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Returns all cached animal records, optionally filtered by [synced] state.
  Future<List<Map<String, dynamic>>> getCachedAnimals({
    bool? synced,
  }) async {
    final db = await database;

    List<Map<String, dynamic>> results;
    if (synced != null) {
      results = await db.query(
        'cached_animals',
        where: 'synced = ?',
        whereArgs: [synced ? 1 : 0],
      );
    } else {
      results = await db.query('cached_animals');
    }

    return results.map((row) {
      return {
        'id': row['id'],
        'data': jsonDecode(row['data'] as String),
        'synced': row['synced'] == 1,
      };
    }).toList();
  }

  /// Returns a single cached animal by [id], or `null` if not found.
  Future<Map<String, dynamic>?> getCachedAnimal(String id) async {
    final db = await database;
    final results = await db.query(
      'cached_animals',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (results.isEmpty) return null;

    final row = results.first;
    return {
      'id': row['id'],
      'data': jsonDecode(row['data'] as String),
      'synced': row['synced'] == 1,
    };
  }

  /// Marks a cached animal as synced.
  Future<int> markAnimalSynced(String id) async {
    final db = await database;
    return db.update(
      'cached_animals',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Deletes a cached animal by [id].
  Future<int> deleteCachedAnimal(String id) async {
    final db = await database;
    return db.delete(
      'cached_animals',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---------------------------------------------------------------------------
  // Cached Form Schemas
  // ---------------------------------------------------------------------------

  /// Inserts or replaces a cached form schema.
  ///
  /// [id] is the schema type identifier (e.g. 'cattle_registration').
  /// [schema] is the full JSON schema map.
  /// [version] is an optional schema version string.
  Future<int> cacheSchema({
    required String id,
    required Map<String, dynamic> schema,
    String? version,
  }) async {
    final db = await database;
    return db.insert(
      'cached_form_schemas',
      {
        'id': id,
        'schema': jsonEncode(schema),
        'version': version,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Returns a cached form schema by [id], or `null` if not found.
  Future<Map<String, dynamic>?> getCachedSchema(String id) async {
    final db = await database;
    final results = await db.query(
      'cached_form_schemas',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (results.isEmpty) return null;

    final row = results.first;
    return {
      'id': row['id'],
      'schema': jsonDecode(row['schema'] as String),
      'version': row['version'],
      'updated_at': row['updated_at'],
    };
  }

  /// Returns all cached form schemas.
  Future<List<Map<String, dynamic>>> getAllCachedSchemas() async {
    final db = await database;
    final results = await db.query('cached_form_schemas');
    return results.map((row) {
      return {
        'id': row['id'],
        'schema': jsonDecode(row['schema'] as String),
        'version': row['version'],
        'updated_at': row['updated_at'],
      };
    }).toList();
  }

  /// Deletes a cached form schema by [id].
  Future<int> deleteCachedSchema(String id) async {
    final db = await database;
    return db.delete(
      'cached_form_schemas',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---------------------------------------------------------------------------
  // Maintenance
  // ---------------------------------------------------------------------------

  /// Closes the database connection. Call on app termination if needed.
  Future<void> close() async {
    final db = _database;
    if (db != null && db.isOpen) {
      await db.close();
      _database = null;
    }
  }

  /// Deletes **all data** from every table. Use with caution.
  Future<void> clearAll() async {
    final db = await database;
    await db.delete('offline_queue');
    await db.delete('cached_animals');
    await db.delete('cached_form_schemas');
  }
}

/// Riverpod provider for [LocalDbService].
final localDbProvider = Provider<LocalDbService>((ref) {
  return LocalDbService();
});
