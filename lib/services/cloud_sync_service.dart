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
  Timer? _periodicSync;

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  void start() {
    if (_started) return;
    _started = true;
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) unawaited(syncCurrentUser());
    });
    _periodicSync = Timer.periodic(const Duration(seconds: 30), (_) {
      if (FirebaseAuth.instance.currentUser != null) unawaited(syncCurrentUser());
    });
  }

  Future<void> syncCurrentUser() async {
    if (_running) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _running = true;
    try {
      await pushOutbox(user.uid);
      await pullLibrary(user.uid);
      await _setState('last_successful_sync', DateTime.now().millisecondsSinceEpoch.toString());
    } on FirebaseException catch (firebaseError) {
      throw CloudSyncException('تعذر مزامنة بياناتك مع السحابة حالياً (${firebaseError.code}).');
    } finally {
      _running = false;
    }
  }

  Future<void> pushOutbox(String uid) async {
    final db = await _local.database;
    final rows = await db.query(
      AppConstants.tableSyncOutbox,
      where: 'synced_at IS NULL',
      orderBy: 'created_at ASC',
      limit: 450,
    );
    if (rows.isEmpty) return;

    final batch = _firestore.batch();
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final row in rows) {
      final entityType = row['entity_type']! as String;
      final entityId = row['entity_id']! as String;
      final operation = row['operation']! as String;
      final payload = jsonDecode(row['payload']! as String) as Map<String, dynamic>;
      final ref = _firestore.collection('users').doc(uid).collection(entityType).doc(entityId);

      batch.set(
        ref,
        {
          ...payload,
          '_sync_updated_at': FieldValue.serverTimestamp(),
          '_sync_deleted': operation == 'DELETE',
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();

    await db.transaction((txn) async {
      for (final row in rows) {
        await txn.update(
          AppConstants.tableSyncOutbox,
          {'synced_at': now},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
    });
  }

  Future<void> pullLibrary(String uid) async {
    final db = await _local.database;
    final state = await db.query(
      AppConstants.tableSyncState,
      where: 'key = ?',
      whereArgs: ['library_last_pull'],
      limit: 1,
    );
    final lastPull = state.isEmpty ? null : int.tryParse(state.first['value']?.toString() ?? '');
    final ref = _firestore.collection('users').doc(uid).collection(AppConstants.tableLibrary);

    Query<Map<String, dynamic>> query = ref;
    if (lastPull != null && lastPull > 0) {
      query = ref.where(
        '_sync_updated_at',
        isGreaterThan: Timestamp.fromMillisecondsSinceEpoch(lastPull),
      );
    }

    final snapshot = await query.get();

    await db.transaction((txn) async {
      for (final doc in snapshot.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        final deleted = data['_sync_deleted'] == true;
        final clean = Map<String, dynamic>.from(data)
          ..remove('_sync_updated_at')
          ..remove('_sync_deleted');

        final key = '${clean['media_type']}:${clean['id']}';
        if (deleted) {
          await txn.delete(AppConstants.tableLibrary, where: 'key = ?', whereArgs: [key]);
        } else {
          await txn.insert(
            AppConstants.tableLibrary,
            {'key': key, 'data': jsonEncode(clean)},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });

    await _setState('library_last_pull', DateTime.now().millisecondsSinceEpoch.toString());
  }

  Future<void> enqueue({
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    if (!const {'INSERT', 'UPDATE', 'DELETE'}.contains(operation)) {
      throw ArgumentError.value(operation, 'operation');
    }

    final db = await _local.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(
      AppConstants.tableSyncOutbox,
      {
        'id': '${now}-${entityType}-${entityId}-${operation}',
        'entity_type': entityType,
        'entity_id': entityId,
        'operation': operation,
        'payload': jsonEncode(payload),
        'created_at': now,
        'synced_at': null,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    _authSubscription = null;
    _periodicSync?.cancel();
    _periodicSync = null;
    _started = false;
  }

  Future<void> _setState(String key, String value) async {
    final db = await _local.database;
    await db.insert(
      AppConstants.tableSyncState,
      {'key': key, 'value': value, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
