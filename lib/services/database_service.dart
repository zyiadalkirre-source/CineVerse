import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../core/constants.dart';
import '../database/tables/content_cache_schema.dart';
import '../models/chat_message.dart';
import '../models/media_item.dart';

class DatabaseService {
  DatabaseService._({Database? database}) : _db = database;

  static final DatabaseService instance = DatabaseService._();

  factory DatabaseService.forTest(Database database) => DatabaseService._(database: database);

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dir, AppConstants.dbName),
      version: AppConstants.dbVersion,
      onCreate: (db, version) => _createSchema(db),
      onUpgrade: _upgradeSchema,
    );
    return _db!;
  }

  static Future<void> createSchemaForTest(Database db) => _createSchema(db);

  static Future<void> _createSchema(Database db) async {
    await db.execute('CREATE TABLE ${AppConstants.tableLibrary} (key TEXT PRIMARY KEY, data TEXT NOT NULL, updated_at INTEGER NOT NULL DEFAULT 0)');
    await db.execute('CREATE TABLE ${AppConstants.tableChat} (id TEXT PRIMARY KEY, data TEXT NOT NULL, created_at INTEGER NOT NULL)');
    await db.execute('CREATE TABLE ${AppConstants.tableSearchHistory} (id INTEGER PRIMARY KEY AUTOINCREMENT, query TEXT NOT NULL, created_at INTEGER NOT NULL)');
    await db.execute('CREATE TABLE ${AppConstants.tableEpisodeProgress} (key TEXT PRIMARY KEY, media_id INTEGER NOT NULL, media_type TEXT NOT NULL, season INTEGER NOT NULL, episode INTEGER NOT NULL, position_seconds INTEGER NOT NULL, duration_seconds INTEGER NOT NULL DEFAULT 0, episode_name TEXT NOT NULL DEFAULT "", updated_at INTEGER NOT NULL)');
    await db.execute('CREATE TABLE ${AppConstants.tableNotifications} (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, body TEXT NOT NULL, created_at INTEGER NOT NULL, read INTEGER NOT NULL DEFAULT 0)');
    await db.execute('CREATE TABLE ${AppConstants.tableSyncOutbox} (id TEXT PRIMARY KEY, entity_type TEXT NOT NULL, entity_id TEXT NOT NULL, operation TEXT NOT NULL, payload TEXT NOT NULL, created_at INTEGER NOT NULL, synced_at INTEGER)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sync_outbox_pending ON ${AppConstants.tableSyncOutbox}(synced_at, created_at)');
    await db.execute('CREATE TABLE ${AppConstants.tableSyncState} (key TEXT PRIMARY KEY, value TEXT NOT NULL, updated_at INTEGER NOT NULL)');
    await ContentCacheSchema.create(db);
  }

  static Future<void> _upgradeSchema(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('CREATE TABLE IF NOT EXISTS ${AppConstants.tableEpisodeProgress} (key TEXT PRIMARY KEY, media_id INTEGER NOT NULL, media_type TEXT NOT NULL, season INTEGER NOT NULL, episode INTEGER NOT NULL, position_seconds INTEGER NOT NULL, duration_seconds INTEGER NOT NULL DEFAULT 0, episode_name TEXT NOT NULL DEFAULT "", updated_at INTEGER NOT NULL)');
      await db.execute('CREATE TABLE IF NOT EXISTS ${AppConstants.tableNotifications} (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, body TEXT NOT NULL, created_at INTEGER NOT NULL, read INTEGER NOT NULL DEFAULT 0)');
    }

    if (oldVersion < 3) {
      await db.execute('CREATE TABLE IF NOT EXISTS ${AppConstants.tableSyncOutbox} (key TEXT PRIMARY KEY, operation TEXT NOT NULL, payload TEXT, created_at INTEGER NOT NULL, attempts INTEGER NOT NULL DEFAULT 0, device_id TEXT NOT NULL)');
      await db.execute('CREATE TABLE IF NOT EXISTS ${AppConstants.tableSyncState} (key TEXT PRIMARY KEY, updated_at INTEGER NOT NULL, device_id TEXT NOT NULL, deleted INTEGER NOT NULL DEFAULT 0, synced INTEGER NOT NULL DEFAULT 0)');
    }

    if (oldVersion < 4) {
      await db.execute('DROP TABLE IF EXISTS ${AppConstants.tableSyncOutbox}');
      await db.execute('DROP TABLE IF EXISTS ${AppConstants.tableSyncState}');
      await db.execute('CREATE TABLE ${AppConstants.tableSyncOutbox} (id TEXT PRIMARY KEY, entity_type TEXT NOT NULL, entity_id TEXT NOT NULL, operation TEXT NOT NULL, payload TEXT NOT NULL, created_at INTEGER NOT NULL, synced_at INTEGER)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_sync_outbox_pending ON ${AppConstants.tableSyncOutbox}(synced_at, created_at)');
      await db.execute('CREATE TABLE ${AppConstants.tableSyncState} (key TEXT PRIMARY KEY, value TEXT NOT NULL, updated_at INTEGER NOT NULL)');
    }

    if (oldVersion < 5) {
      await ContentCacheSchema.create(db);
    }

    if (oldVersion < 6) {
      await db.execute(
        'ALTER TABLE ${AppConstants.tableLibrary} ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0',
      );
      final migrationTime = DateTime.now().millisecondsSinceEpoch;
      await db.rawUpdate(
        'UPDATE ${AppConstants.tableLibrary} SET updated_at = ? WHERE updated_at = 0',
        [migrationTime],
      );
    }
  }

  Future<List<MediaItem>> getLibrary() async {
    final rows = await (await database).query(AppConstants.tableLibrary);
    return rows
        .map((r) => MediaItem.fromJson(jsonDecode(r['data']! as String) as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveMedia(MediaItem item, {bool enqueueSync = true}) async {
    final db = await database;
    await db.insert(
      AppConstants.tableLibrary,
      {
        'key': '${item.mediaType}:${item.id}',
        'data': jsonEncode(item.toJson()),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    if (enqueueSync) {
      await _enqueueMediaChange(db, item, 'UPDATE');
    }
  }

  Future<void> deleteLibrary({bool enqueueSync = true}) async {
    final db = await database;
    if (!enqueueSync) {
      await db.delete(AppConstants.tableLibrary);
      return;
    }

    final rows = await db.query(AppConstants.tableLibrary);
    await db.delete(AppConstants.tableLibrary);

    for (final row in rows) {
      final item = MediaItem.fromJson(jsonDecode(row['data']! as String) as Map<String, dynamic>);
      await _enqueueMediaChange(db, item, 'DELETE');
    }
  }

  Future<void> deleteMedia(MediaItem item, {bool enqueueSync = true}) async {
    final db = await database;
    await db.delete(
      AppConstants.tableLibrary,
      where: 'key = ?',
      whereArgs: ['${item.mediaType}:${item.id}'],
    );
    if (enqueueSync) {
      await _enqueueMediaChange(db, item, 'DELETE');
    }
  }

  Future<void> _enqueueMediaChange(Database db, MediaItem item, String operation) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final uniqueId = DateTime.now().microsecondsSinceEpoch;
    final entityId = '${item.mediaType}:${item.id}';

    await db.insert(
      AppConstants.tableSyncOutbox,
      {
        'id': '${uniqueId}-${entityId}-${operation}',
        'entity_type': AppConstants.tableLibrary,
        'entity_id': entityId,
        'operation': operation,
        'payload': jsonEncode(item.toJson()),
        'created_at': timestamp,
        'synced_at': null,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<MediaItem?> getCachedMedia(int id, String mediaType) async {
    final rows = await (await database).query(
      AppConstants.tableMediaCache,
      columns: ['id', 'media_type', 'json_data', 'cached_at'],
      where: 'id = ? AND media_type = ?',
      whereArgs: [id, mediaType],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    return MediaItem.fromJson(
      jsonDecode(rows.first['json_data']! as String) as Map<String, dynamic>,
    );
  }

  Future<Map<String, dynamic>?> getCachedMediaRecord(int id, String mediaType) async {
    final rows = await (await database).query(
      AppConstants.tableMediaCache,
      where: 'id = ? AND media_type = ?',
      whereArgs: [id, mediaType],
      limit: 1,
    );

    return rows.isEmpty ? null : Map<String, dynamic>.from(rows.first);
  }

  Future<List<MediaItem>> getCachedMediaByKeys(Iterable<String> keys) async {
    final normalized = keys.toList();
    if (normalized.isEmpty) return [];

    final result = <MediaItem>[];
    final db = await database;

    for (final key in normalized) {
      final separator = key.indexOf(':');
      if (separator <= 0 || separator >= key.length - 1) continue;

      final mediaType = key.substring(0, separator);
      final id = int.tryParse(key.substring(separator + 1));
      if (id == null) continue;

      final rows = await db.query(
        AppConstants.tableMediaCache,
        where: 'id = ? AND media_type = ?',
        whereArgs: [id, mediaType],
        limit: 1,
      );

      if (rows.isEmpty) continue;

      result.add(
        MediaItem.fromJson(
          jsonDecode(rows.first['json_data']! as String) as Map<String, dynamic>,
        ),
      );
    }

    return result;
  }

  Future<void> cacheMediaItems(List<MediaItem> items, {int? cachedAt}) async {
    if (items.isEmpty) return;

    final db = await database;
    final now = cachedAt ?? DateTime.now().millisecondsSinceEpoch;

    await db.transaction((txn) async {
      for (final item in items) {
        await txn.insert(
          AppConstants.tableMediaCache,
          {
            'id': item.id,
            'media_type': item.mediaType,
            'json_data': jsonEncode(item.toJson()),
            'cached_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<Map<String, dynamic>?> getCachedCollection(String categoryKey) async {
    final rows = await (await database).query(
      AppConstants.tableTrendingCache,
      where: 'category_key = ?',
      whereArgs: [categoryKey],
      limit: 1,
    );

    return rows.isEmpty ? null : Map<String, dynamic>.from(rows.first);
  }

  Future<List<MediaItem>> getCachedCollectionItems(String categoryKey) async {
    final row = await getCachedCollection(categoryKey);
    if (row == null) return [];

    try {
      final rawIds = jsonDecode(row['media_ids_json']! as String);
      if (rawIds is! List) return [];
      return getCachedMediaByKeys(rawIds.whereType<String>());
    } catch (_) {
      return [];
    }
  }

  Future<void> cacheCollection(
    String categoryKey,
    List<MediaItem> items, {
    int? cachedAt,
  }) async {
    final db = await database;
    final now = cachedAt ?? DateTime.now().millisecondsSinceEpoch;
    final ids = items
        .map((item) => '${item.mediaType}:${item.id}')
        .toList(growable: false);

    await db.transaction((txn) async {
      for (final item in items) {
        await txn.insert(
          AppConstants.tableMediaCache,
          {
            'id': item.id,
            'media_type': item.mediaType,
            'json_data': jsonEncode(item.toJson()),
            'cached_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await txn.insert(
        AppConstants.tableTrendingCache,
        {
          'category_key': categoryKey,
          'media_ids_json': jsonEncode(ids),
          'cached_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<void> cacheDetails(MediaItem item, {int? cachedAt}) =>
      cacheMediaItems([item], cachedAt: cachedAt);

  Future<int> pruneExpiredCache({
    Duration maxAge = const Duration(days: 7),
  }) async {
    if (maxAge.isNegative) {
      throw ArgumentError.value(
        maxAge,
        'maxAge',
        'Cache maxAge cannot be negative',
      );
    }

    final db = await database;
    final threshold = DateTime.now().subtract(maxAge).millisecondsSinceEpoch;

    return db.transaction((txn) async {
      final deletedMediaCount = await txn.delete(
        AppConstants.tableMediaCache,
        where: '''
          cached_at < ?
          AND NOT EXISTS (
            SELECT 1
            FROM ${AppConstants.tableLibrary} AS library
            WHERE library.key =
              ${AppConstants.tableMediaCache}.media_type
              || ':'
              || CAST(${AppConstants.tableMediaCache}.id AS TEXT)
          )
        ''',
        whereArgs: [threshold],
      );

      await txn.delete(
        AppConstants.tableTrendingCache,
        where: 'cached_at < ?',
        whereArgs: [threshold],
      );

      return deletedMediaCount;
    });
  }

  Future<void> clearContentCache() async {
    final db = await database;

    await db.transaction((txn) async {
      await txn.delete(AppConstants.tableMediaCache);
      await txn.delete(AppConstants.tableTrendingCache);
    });
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
