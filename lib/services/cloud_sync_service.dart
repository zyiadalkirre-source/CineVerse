import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sqflite/sqflite.dart';

import '../core/constants.dart';
import '../core/firebase_bootstrap.dart';
import '../models/media_item.dart';
import 'database_service.dart';

class CloudSyncException implements Exception {
  const CloudSyncException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CloudSyncService {
  CloudSyncService._({
    DatabaseService? local,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _local = local ?? DatabaseService.instance,
        _firestoreOverride = firestore,
        _authOverride = auth;

  static final instance = CloudSyncService._();

  factory CloudSyncService.forTest({
    required DatabaseService local,
    required FirebaseFirestore firestore,
    FirebaseAuth? auth,
  }) {
    return CloudSyncService._(
      local: local,
      firestore: firestore,
      auth: auth,
    );
  }

  final DatabaseService _local;
  final FirebaseFirestore? _firestoreOverride;
  final FirebaseAuth? _authOverride;
  final Random _random = Random();

  StreamSubscription<User?>? _authSubscription;
  bool _running = false;
  bool _started = false;
  Timer? _periodicSync;
  Timer? _retryTimer;
  int _retryAttempt = 0;

  static const Duration _periodicInterval = Duration(seconds: 30);
  static const Duration _baseBackoff = Duration(seconds: 2);
  static const Duration _maxBackoff = Duration(minutes: 5);
  static const Duration _pullClockSkew = Duration(minutes: 2);

  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  void start() {
    if (!FirebaseBootstrap.configured) {
      debugPrint('ℹ️ Cloud sync skipped: Firebase is not configured.');
      return;
    }
    if (_started) return;

    _started = true;

    _authSubscription = _auth.authStateChanges().listen((user) {
      if (user == null) {
        _cancelRetry();
        _retryAttempt = 0;
        return;
      }

      unawaited(_runSyncSafely());
    });

    _periodicSync = Timer.periodic(_periodicInterval, (_) {
      if (_auth.currentUser == null || _retryTimer?.isActive == true) {
        return;
      }
      unawaited(_runSyncSafely());
    });
  }

  Future<void> _runSyncSafely() async {
    try {
      await syncCurrentUser();
    } catch (_) {}
  }

  Future<void> syncCurrentUser() async {
    if (!FirebaseBootstrap.configured) {
      throw const CloudSyncException(
        'Firebase غير مهيأ، لذلك لا يمكن مزامنة البيانات السحابية.',
      );
    }
    if (_running) return;

    final user = _auth.currentUser;
    if (user == null) return;

    _running = true;

    try {
      await pushOutbox(user.uid);
      await pullLibrary(user.uid);
      await _setState(
        'last_successful_sync',
        DateTime.now().millisecondsSinceEpoch.toString(),
      );
      _retryAttempt = 0;
      _cancelRetry();
    } on FirebaseException catch (firebaseError) {
      if (_isRetryableFirebaseError(firebaseError)) {
        _scheduleRetry();
      }
      throw CloudSyncException(
        'تعذر مزامنة بياناتك مع السحابة حالياً (' +
        firebaseError.code +
        ').',
      );
    } on SocketException catch (_) {
      _scheduleRetry();
      throw const CloudSyncException(
        'تعذر الاتصال بالسحابة حالياً. ستتم إعادة المحاولة تلقائياً.',
      );
    } on TimeoutException catch (_) {
      _scheduleRetry();
      throw const CloudSyncException(
        'انتهت مهلة مزامنة البيانات. ستتم إعادة المحاولة تلقائياً.',
      );
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
      final payload =
          jsonDecode(row['payload']! as String) as Map<String, dynamic>;
      final createdAt = row['created_at'] is int
          ? row['created_at']! as int
          : now;

      final ref = _firestore
          .collection('users')
          .doc(uid)
          .collection(entityType)
          .doc(entityId);

      batch.set(
        ref,
        {
          ...payload,
          '_sync_client_updated_at': createdAt,
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

    final savedPull = state.isEmpty
        ? null
        : int.tryParse(state.first['value']?.toString() ?? '');

    final ref = _firestore
        .collection('users')
        .doc(uid)
        .collection(AppConstants.tableLibrary);

    Query<Map<String, dynamic>> query = ref;
    if (savedPull != null && savedPull > 0) {
      final lowerBound = max(
        0,
        savedPull - _pullClockSkew.inMilliseconds,
      );
      query = ref.where(
        '_sync_updated_at',
        isGreaterThan: Timestamp.fromMillisecondsSinceEpoch(lowerBound),
      );
    }

    final snapshot = await query.get();
    var newestRemoteTimestamp = savedPull ?? 0;

    await db.transaction((txn) async {
      for (final doc in snapshot.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        final mediaType = data['media_type']?.toString().trim();
        final id = data['id'] is num
            ? (data['id'] as num).toInt()
            : int.tryParse(data['id']?.toString() ?? '');

        if (mediaType == null ||
            mediaType.isEmpty ||
            id == null ||
            id <= 0) {
          continue;
        }

        final remoteUpdatedAt = _remoteUpdatedAt(data);
        if (remoteUpdatedAt != null) {
          newestRemoteTimestamp = max(
            newestRemoteTimestamp,
            remoteUpdatedAt,
          );
        }

        final key = mediaType + ':' + id.toString();
        final localRows = await txn.query(
          AppConstants.tableLibrary,
          columns: ['updated_at'],
          where: 'key = ?',
          whereArgs: [key],
          limit: 1,
        );

        final localUpdatedAt = localRows.isEmpty
            ? null
            : _asInt(localRows.first['updated_at']);

        if (remoteUpdatedAt != null &&
            localUpdatedAt != null &&
            localUpdatedAt >= remoteUpdatedAt) {
          continue;
        }

        // The remote version has won LWW. Any still-pending local
        // outbox entries that are not newer than this remote version are now
        // obsolete and must not be allowed to resurrect stale data later.
        if (remoteUpdatedAt != null) {
          await txn.update(
            AppConstants.tableSyncOutbox,
            {'synced_at': DateTime.now().millisecondsSinceEpoch},
            where: '''
              entity_type = ?
              AND entity_id = ?
              AND synced_at IS NULL
              AND created_at <= ?
            ''',
            whereArgs: [
              AppConstants.tableLibrary,
              key,
              remoteUpdatedAt,
            ],
          );
        }

        final deleted = data['_sync_deleted'] == true;
        final clean = Map<String, dynamic>.from(data)
          ..remove('_sync_updated_at')
          ..remove('_sync_client_updated_at')
          ..remove('_sync_deleted');

        if (deleted) {
          await txn.delete(
            AppConstants.tableLibrary,
            where: 'key = ?',
            whereArgs: [key],
          );
          continue;
        }

        final effectiveUpdatedAt =
            remoteUpdatedAt ?? DateTime.now().millisecondsSinceEpoch;

        await txn.insert(
          AppConstants.tableLibrary,
          {
            'key': key,
            'data': jsonEncode(clean),
            'updated_at': effectiveUpdatedAt,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });

    if (newestRemoteTimestamp > 0) {
      await _setState(
        'library_last_pull',
        newestRemoteTimestamp.toString(),
      );
    }
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
    final now = DateTime.now().microsecondsSinceEpoch;

    await db.insert(
      AppConstants.tableSyncOutbox,
      {
        'id':
            now.toString() + '-' + entityType + '-' + entityId + '-' + operation,
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

  void _scheduleRetry() {
    if (!_started || _auth.currentUser == null) return;
    if (_retryTimer?.isActive == true) return;

    final exponent = min(_retryAttempt, 8);
    final baseMilliseconds = _baseBackoff.inMilliseconds * pow(2, exponent);
    final cappedMilliseconds = min(
      baseMilliseconds.toInt(),
      _maxBackoff.inMilliseconds,
    );
    final jitter = _random.nextInt(501);
    final delay = Duration(
      milliseconds: cappedMilliseconds + jitter,
    );

    _retryAttempt = min(_retryAttempt + 1, 8);
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      unawaited(_runSyncSafely());
    });
  }

  void _cancelRetry() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  bool _isRetryableFirebaseError(FirebaseException error) {
    const nonRetryable = <String>{
      'permission-denied',
      'unauthenticated',
      'failed-precondition',
    };
    return !nonRetryable.contains(error.code);
  }

  int? _remoteUpdatedAt(Map<String, dynamic> data) {
    final clientValue = _asInt(data['_sync_client_updated_at']);
    if (clientValue != null && clientValue > 0) {
      return clientValue;
    }

    final serverValue = data['_sync_updated_at'];
    if (serverValue is Timestamp) {
      return serverValue.millisecondsSinceEpoch;
    }

    return null;
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  /// Backwards-compatible manual sync entry point.
  ///
  /// Library changes are already persisted through DatabaseService and the
  /// outbox, so the argument is intentionally not written again here.
  Future<void> syncLibrary(List<MediaItem> library) async {
    await syncCurrentUser();
  }

  /// Pulls the current user's library and returns the resulting local state.
  Future<List<MediaItem>> downloadLibrary() async {
    if (!FirebaseBootstrap.configured) {
      return _local.getLibrary();
    }
    final user = _auth.currentUser;
    if (user != null) {
      await pullLibrary(user.uid);
    }
    return _local.getLibrary();
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    _authSubscription = null;
    _periodicSync?.cancel();
    _periodicSync = null;
    _cancelRetry();
    _started = false;
  }

  Future<void> _setState(String key, String value) async {
    final db = await _local.database;

    await db.insert(
      AppConstants.tableSyncState,
      {
        'key': key,
        'value': value,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
