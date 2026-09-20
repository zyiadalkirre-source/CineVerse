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
    _db = await openDatabase(p.join(dir, AppConstants.dbName), version: AppConstants.dbVersion,
      onCreate: (db, version) async {
        await db.execute('CREATE TABLE ${AppConstants.tableLibrary} (key TEXT PRIMARY KEY, data TEXT NOT NULL)');
        await db.execute('CREATE TABLE ${AppConstants.tableChat} (id TEXT PRIMARY KEY, data TEXT NOT NULL, created_at INTEGER NOT NULL)');
        await db.execute('CREATE TABLE ${AppConstants.tableSearchHistory} (id INTEGER PRIMARY KEY AUTOINCREMENT, query TEXT NOT NULL, created_at INTEGER NOT NULL)');
      });
    return _db!;
  }
  Future<List<MediaItem>> getLibrary() async {
    final rows = await (await database).query(AppConstants.tableLibrary);
    return rows.map((r)=>MediaItem.fromJson(jsonDecode(r['data']! as String) as Map<String,dynamic>)).toList();
  }
  Future<void> saveMedia(MediaItem item) async {
    await (await database).insert(AppConstants.tableLibrary, {'key':'${item.mediaType}:${item.id}','data':jsonEncode(item.toJson())}, conflictAlgorithm:ConflictAlgorithm.replace);
  }
  Future<void> deleteLibrary() async => (await database).delete(AppConstants.tableLibrary);
  Future<void> deleteMedia(MediaItem item) async => (await database).delete(AppConstants.tableLibrary, where: 'key = ?', whereArgs: ['${item.mediaType}:${item.id}']);
  Future<void> saveChat(ChatMessage message) async {
    await (await database).insert(AppConstants.tableChat, {'id':message.id,'data':jsonEncode(message.toJson()),'created_at':message.createdAt.millisecondsSinceEpoch}, conflictAlgorithm:ConflictAlgorithm.replace);
  }
  Future<List<ChatMessage>> getChat({int limit=100}) async {
    final rows=await (await database).query(AppConstants.tableChat,orderBy:'created_at ASC',limit:limit);
    return rows.map((r)=>ChatMessage.fromJson(jsonDecode(r['data']! as String) as Map<String,dynamic>)).toList();
  }
  Future<void> clearChat() async => (await database).delete(AppConstants.tableChat);
  Future<void> addSearch(String query) async {
    if(query.trim().isEmpty)return;
    await (await database).insert(AppConstants.tableSearchHistory,{'query':query.trim(),'created_at':DateTime.now().millisecondsSinceEpoch});
  }
  Future<List<String>> getSearchHistory({int limit=30}) async {
    final rows=await (await database).query(AppConstants.tableSearchHistory,columns:['query'],orderBy:'created_at DESC',limit:limit);
    return rows.map((r)=>r['query']! as String).toList();
  }
}