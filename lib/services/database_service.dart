import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../core/constants.dart';
import '../models/chat_message.dart';
import '../models/media_item.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dir, AppConstants.dbName),
      version: AppConstants.dbVersion,
      onCreate: (db, version) async {
        await db.execute('CREATE TABLE ${AppConstants.tableLibrary} (key TEXT PRIMARY KEY, data TEXT NOT NULL)');
        await db.execute('CREATE TABLE ${AppConstants.tableChat} (id TEXT PRIMARY KEY, data TEXT NOT NULL, created_at INTEGER NOT NULL)');
        await db.execute('CREATE TABLE ${AppConstants.tableSearchHistory} (id INTEGER PRIMARY KEY AUTOINCREMENT, query TEXT NOT NULL, created_at INTEGER NOT NULL)');
        await db.execute('CREATE TABLE ${AppConstants.tableEpisodeProgress} (key TEXT PRIMARY KEY, media_id INTEGER NOT NULL, media_type TEXT NOT NULL, season INTEGER NOT NULL, episode INTEGER NOT NULL, position_seconds INTEGER NOT NULL, duration_seconds INTEGER NOT NULL DEFAULT 0, episode_name TEXT NOT NULL DEFAULT "", updated_at INTEGER NOT NULL)');
        await db.execute('CREATE TABLE ${AppConstants.tableNotifications} (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, body TEXT NOT NULL, created_at INTEGER NOT NULL, read INTEGER NOT NULL DEFAULT 0)');
        await db.execute('CREATE TABLE ${AppConstants.tableSyncOutbox} (id TEXT PRIMARY KEY, entity_type TEXT NOT NULL, entity_id TEXT NOT NULL, operation TEXT NOT NULL, payload TEXT NOT NULL, created_at INTEGER NOT NULL, synced_at INTEGER)');
        await db.execute('CREATE TABLE ${AppConstants.tableSyncState} (key TEXT PRIMARY KEY, value TEXT NOT NULL, updated_at INTEGER NOT NULL)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('CREATE TABLE IF NOT EXISTS ${AppConstants.tableEpisodeProgress} (key TEXT PRIMARY KEY, media_id INTEGER NOT NULL, media_type TEXT NOT NULL, season INTEGER NOT NULL, episode INTEGER NOT NULL, position_seconds INTEGER NOT NULL, duration_seconds INTEGER NOT NULL DEFAULT 0, episode_name TEXT NOT NULL DEFAULT "", updated_at INTEGER NOT NULL)');
          await db.execute('CREATE TABLE IF NOT EXISTS ${AppConstants.tableNotifications} (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, body TEXT NOT NULL, created_at INTEGER NOT NULL, read INTEGER NOT NULL DEFAULT 0)');
        }
        if (oldVersion < 3) {
          await db.execute('CREATE TABLE IF NOT EXISTS ${AppConstants.tableSyncOutbox} (key TEXT PRIMARY KEY, operation TEXT NOT NULL, payload TEXT, created_at INTEGER NOT NULL, attempts INTEGER NOT NULL DEFAULT 0, device_id TEXT NOT NULL)');
          await db.execute('CREATE TABLE IF NOT EXISTS ${AppConstants.tableSyncState} (key TEXT PRIMARY KEY, updated_at INTEGER NOT NULL, device_id TEXT NOT NULL, deleted INTEGER NOT NULL DEFAULT 0, synced INTEGER NOT NULL DEFAULT 0)');
        }
      },
    );
    return _db!;
  }

  Future<List<MediaItem>> getLibrary() async {
    final rows = await (await database).query(AppConstants.tableLibrary);
    return rows.map((r) => MediaItem.fromJson(jsonDecode(r['data']! as String) as Map<String, dynamic>)).toList();
  }

  Future<void> saveMedia(MediaItem item) async {
    await (await database).insert(
      AppConstants.tableLibrary,
      {'key': '${item.mediaType}:${item.id}', 'data': jsonEncode(item.toJson())},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteLibrary() async => (await database).delete(AppConstants.tableLibrary);

  Future<void> deleteMedia(MediaItem item) async => (await database).delete(
        AppConstants.tableLibrary,
        where: 'key = ?',
        whereArgs: ['${item.mediaType}:${item.id}'],
      );

  Future<void> saveChat(ChatMessage message) async {
    await (await database).insert(
      AppConstants.tableChat,
      {'id': message.id, 'data': jsonEncode(message.toJson()), 'created_at': message.createdAt.millisecondsSinceEpoch},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ChatMessage>> getChat({int limit = 100}) async {
    final rows = await (await database).query(
      AppConstants.tableChat,
      orderBy: 'created_at ASC',
      limit: limit,
    );
    return rows.map((r) => ChatMessage.fromJson(jsonDecode(r['data']! as String) as Map<String, dynamic>)).toList();
  }

  Future<void> clearChat() async => (await database).delete(AppConstants.tableChat);

  Future<void> addSearch(String query) async {
    if (query.trim().isEmpty) return;
    await (await database).insert(
      AppConstants.tableSearchHistory,
      {'query': query.trim(), 'created_at': DateTime.now().millisecondsSinceEpoch},
    );
  }

  Future<List<String>> getSearchHistory({int limit = 30}) async {
    final rows = await (await database).query(
      AppConstants.tableSearchHistory,
      columns: ['query'],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map((r) => r['query']! as String).toList();
  }

  String episodeProgressKey({required int mediaId, required String mediaType, required int season, required int episode}) =>
      '${mediaType}:${mediaId}:${season}:${episode}';

  Future<void> saveEpisodeProgress({
    required int mediaId,
    required String mediaType,
    required int season,
    required int episode,
    required int positionSeconds,
    required int durationSeconds,
    String episodeName = '',
  }) async {
    await (await database).insert(
      AppConstants.tableEpisodeProgress,
      {
        'key': episodeProgressKey(mediaId: mediaId, mediaType: mediaType, season: season, episode: episode),
        'media_id': mediaId,
        'media_type': mediaType,
        'season': season,
        'episode': episode,
        'position_seconds': positionSeconds,
        'duration_seconds': durationSeconds,
        'episode_name': episodeName,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getEpisodeProgress({
    required int mediaId,
    required String mediaType,
    required int season,
    required int episode,
  }) async {
    final rows = await (await database).query(
      AppConstants.tableEpisodeProgress,
      where: 'key = ?',
      whereArgs: [episodeProgressKey(mediaId: mediaId, mediaType: mediaType, season: season, episode: episode)],
      limit: 1,
    );
    return rows.isEmpty ? null : Map<String, dynamic>.from(rows.first);
  }

  Future<List<Map<String, dynamic>>> getEpisodeHistory({int limit = 50}) async {
    final rows = await (await database).query(
      AppConstants.tableEpisodeProgress,
      orderBy: 'updated_at DESC',
      limit: limit,
    );
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<void> addNotification({required String title, required String body}) async {
    await (await database).insert(AppConstants.tableNotifications, {
      'title': title,
      'body': body,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'read': 0,
    });
  }

  Future<List<Map<String, dynamic>>> getNotifications({int limit = 100}) async {
    final rows = await (await database).query(
      AppConstants.tableNotifications,
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<void> markAllNotificationsRead() async {
    await (await database).update(AppConstants.tableNotifications, {'read': 1});
  }

  Future<void> clearNotifications() async {
    await (await database).delete(AppConstants.tableNotifications);
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}