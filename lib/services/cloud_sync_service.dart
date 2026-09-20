import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sqflite/sqflite.dart';

import '../core/constants.dart';
import 'database_service.dart';

class CloudSyncException implements Exception {
  const CloudSyncException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CloudSyncService {
  CloudSyncService._();
  static final instance = CloudSyncService._();

  final DatabaseService _local = DatabaseService.instance;
  StreamSubscription<User?>? _authSubscription;
  bool _running = false;
  bool _started = false;

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  void start() {
    if (_started) return;
    _started = true;
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        unawaited(syncCurrentUser());
      }
    });
  }

  Future<void> syncCurrentUser() async {
    if (_running) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _running = true;
    try {
      await _ensureSchema();
      await pushOutbox(user.uid);
      await pullLibrary(user.uid);
      await _setState('last_successful_sync', DateTime.now().millisecondsSinceEpoch.toString());
    } finally {
      _running = false;
    }
  }

  Future<void> enqueue({
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    if (!['INSERT', 'UPDATE', 'DELETE'].contains(operation)) {
      throw ArgumentError.value(operation, 'operation');
    }
    final db = await _local.database;
    await _ensureSchema(db: db);
    await db.insert(
      AppConstants.tableSyncOutbox,
      {
        'id': '${DateTime.now().microsecondsSinceEpoch}-${entityType}-${entityId}',
        'entity_type': entityType,
        'entity_id': entityId,
        'operation': operation,
        'payload': jsonEncode(payload),
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'synced_at': null,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> pushOutbox(String uid) async {
    final db = await _local.database;
    await _ensureSchema(db: db);
    final rows = await db.query(
      AppConstants.tableSyncOutbox,
      where: 'synced_at IS NULL',
      orderBy: 'created_at ASC',
      limit: 450,
    );
    if (rows.isEmpty) return;

    final batch = _firestore.collection('users').doc(uid).collection('entities').doc();
    final writes = _firestore.batch();

    for (final row in rows) {
      final entityType = row['entity_type']! as String;
      final entityId = row['entity_id']! as String;
      final operation = row['operation']! as String;
      final payload = jsonDecode(row['payload']! as String) as Map<String, dynamic>;
      final ref = _firestore.collection('users').doc(uid).collection(entityType).doc(entityId);
      final serverPayload = <String, dynamic>{
        ...payload,
        '_sync_updated_at': FieldValue.serverTimestamp(),
        '_sync_deleted': operation == 'DELETE',
      };

      if (operation == 'DELETE') {
        writes.set(ref, serverPayload, SetOptions(merge: true));
      } else {
        writes.set(ref, serverPayload, SetOptions(merge: true));
      }
    }

    await writes.commit();

    final syncedAt = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      for (final row in rows) {
        await txn.update(
          AppConstants.tableSyncOutbox,
          {'synced_at': syncedAt},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
    });
    batch;
  }

  Future<void> pullLibrary(String uid) async {
    final ref = _firestore.collection('users').doc(uid).collection(AppConstants.tableLibrary);
    final snapshot = await ref.get();
    final db = await _local.database;
    await _ensureSchema(db: db);

    await db.transaction((txn) async {
      for (final doc in snapshot.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        final deleted = data['_sync_deleted'] == true;
        final clean = Map<String, dynamic>.from(data)
          ..remove('_sync_updated_at')
          ..remove('_sync_deleted');

        if (deleted) {
          await txn.delete(
            AppConstants.tableLibrary,
            where: 'key = ?',
            whereArgs: ['${clean['media_type']}:${clean['id']}'],
          );
        } else {
          await txn.insert(
            AppConstants.tableLibrary,
            {
              'key': '${clean['media_type']}:${clean['id']}',
              'data': jsonEncode(clean),
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });

    await _setState('library_last_pull', DateTime.now().millisecondsSinceEpoch.toString());
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    _authSubscription = null;
    _started = false;
  }

  Future<void> _setState(String key, String value) async {
    final db = await _local.database;
    await _ensureSchema(db: db);
    await db.insert(
      AppConstants.tableSyncState,
      {'key': key, 'value': value, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _ensureSchema({Database? db}) async {
    final database = db ?? await _local.database;
    final outboxColumns = await database.rawQuery('PRAGMA table_info(${AppConstants.tableSyncOutbox})');
    final names = outboxColumns.map((row) => row['name']?.toString()).whereType<String>().toSet();
    if (names.isEmpty) {
      await database.execute('CREATE TABLE IF NOT EXISTS ${AppConstants.tableSyncOutbox} (id TEXT PRIMARY KEY, entity_type TEXT NOT NULL, entity_id TEXT NOT NULL, operation TEXT NOT NULL, payload TEXT NOT NULL, created_at INTEGER NOT NULL, synced_at INTEGER)');
    } else if (!names.contains('entity_type')) {
      await database.execute('ALTER TABLE ${AppConstants.tableSyncOutbox} RENAME TO ${AppConstants.tableSyncOutbox}_legacy');
      await database.execute('CREATE TABLE ${AppConstants.tableSyncOutbox} (id TEXT PRIMARY KEY, entity_type TEXT NOT NULL, entity_id TEXT NOT NULL, operation TEXT NOT NULL, payload TEXT NOT NULL, created_at INTEGER NOT NULL, synced_at INTEGER)');
    }

    await database.execute('CREATE TABLE IF NOT EXISTS ${AppConstants.tableSyncState} (key TEXT PRIMARY KEY, value TEXT NOT NULL, updated_at INTEGER NOT NULL)');
  }
}
