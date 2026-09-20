import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:cineverse/core/constants.dart';
import 'package:cineverse/models/media_item.dart';
import 'package:cineverse/services/cloud_sync_service.dart';
import 'package:cineverse/services/database_service.dart';

void main() {
  late Database rawDatabase;
  late DatabaseService database;
  late FakeFirebaseFirestore firestore;
  late CloudSyncService sync;

  setUp(() async {
    sqfliteFfiInit();

    rawDatabase = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: AppConstants.dbVersion,
        onCreate: (db, version) =>
            DatabaseService.createSchemaForTest(db),
      ),
    );

    database = DatabaseService.forTest(rawDatabase);
    firestore = FakeFirebaseFirestore();
    sync = CloudSyncService.forTest(
      local: database,
      firestore: firestore,
    );
  });

  tearDown(() async {
    await sync.dispose();
    await database.close();
  });

  MediaItem buildItem(int id, {String title = 'Test Movie'}) {
    return MediaItem(
      id: id,
      title: title,
      overview: 'Test overview',
      mediaType: AppConstants.typeMovie,
      voteAverage: 8.5,
      voteCount: 1200,
      releaseDate: '2026-01-01',
    );
  }

  test(
    'writes a local media item to library and creates a pending outbox row',
    () async {
      final item = buildItem(101);
      await database.saveMedia(item);

      final libraryRows = await rawDatabase.query(
        AppConstants.tableLibrary,
        where: 'key = ?',
        whereArgs: ['movie:101'],
      );
      final outboxRows = await rawDatabase.query(
        AppConstants.tableSyncOutbox,
        where: 'entity_id = ?',
        whereArgs: ['movie:101'],
      );

      expect(libraryRows, hasLength(1));
      expect(outboxRows, hasLength(1));
      expect(outboxRows.single['entity_type'], AppConstants.tableLibrary);
      expect(outboxRows.single['operation'], 'UPDATE');
      expect(outboxRows.single['payload'], isNotEmpty);
      expect(outboxRows.single['created_at'], isA<int>());
      expect(outboxRows.single['synced_at'], isNull);
    },
  );

  test(
    'pushes pending outbox rows and records a real synced_at timestamp',
    () async {
      final item = buildItem(202);
      await database.saveMedia(item);

      final before = DateTime.now().millisecondsSinceEpoch;
      await sync.pushOutbox('test-user');
      final after = DateTime.now().millisecondsSinceEpoch;

      final outboxRows = await rawDatabase.query(
        AppConstants.tableSyncOutbox,
        where: 'entity_id = ?',
        whereArgs: ['movie:202'],
        limit: 1,
      );

      expect(outboxRows, hasLength(1));

      final syncedAt = outboxRows.single['synced_at'];
      expect(syncedAt, isA<int>());
      expect(
        syncedAt as int,
        allOf(greaterThanOrEqualTo(before), lessThanOrEqualTo(after)),
      );

      final cloudDocument = await firestore
          .collection('users')
          .doc('test-user')
          .collection(AppConstants.tableLibrary)
          .doc('movie:202')
          .get();

      expect(cloudDocument.exists, isTrue);
      expect(cloudDocument.data()?['id'], 202);
      expect(cloudDocument.data()?['_sync_deleted'], isFalse);
      expect(cloudDocument.data()?['_sync_updated_at'], isNotNull);
    },
  );

  test(
    'pulls a Firestore media item into SQLite without creating an outbox row',
    () async {
      const uid = 'remote-user';
      await firestore
          .collection('users')
          .doc(uid)
          .collection(AppConstants.tableLibrary)
          .doc('movie:303')
          .set({
        'id': 303,
        'title': 'Remote Movie',
        'overview': 'Downloaded from Firestore',
        'media_type': AppConstants.typeMovie,
        'vote_average': 7.9,
        'vote_count': 700,
        'release_date': '2026-02-02',
        'genres': <String>['Drama'],
        'cast': <String>[],
        '_sync_deleted': false,
        '_sync_updated_at': FieldValue.serverTimestamp(),
      });

      await sync.pullLibrary(uid);

      final libraryRows = await rawDatabase.query(
        AppConstants.tableLibrary,
        where: 'key = ?',
        whereArgs: ['movie:303'],
      );
      final outboxRows = await rawDatabase.query(
        AppConstants.tableSyncOutbox,
      );

      expect(libraryRows, hasLength(1));
      expect(outboxRows, isEmpty);

      final stored = MediaItem.fromJson(
        (jsonDecode(libraryRows.single['data']! as String))
            as Map<String, dynamic>,
      );

      expect(stored.id, 303);
      expect(stored.title, 'Remote Movie');
      expect(stored.mediaType, AppConstants.typeMovie);
      expect(stored.voteAverage, 7.9);
    },
  );
  test(
    'does not overwrite a newer local library item with an older Firestore version',
    () async {
      const uid = 'lww-user';
      final localItem = MediaItem(
        id: 404,
        title: 'Local Newer Movie',
        overview: 'Local version',
        mediaType: AppConstants.typeMovie,
        voteAverage: 9.2,
        voteCount: 1000,
      );

      await database.saveMedia(localItem);

      final localRows = await rawDatabase.query(
        AppConstants.tableLibrary,
        where: 'key = ?',
        whereArgs: ['movie:404'],
        limit: 1,
      );
      final localUpdatedAt =
          localRows.single['updated_at'] as int;

      await firestore
          .collection('users')
          .doc(uid)
          .collection(AppConstants.tableLibrary)
          .doc('movie:404')
          .set({
        'id': 404,
        'title': 'Older Cloud Movie',
        'overview': 'Older remote version',
        'media_type': AppConstants.typeMovie,
        'vote_average': 1.0,
        'vote_count': 1,
        '_sync_deleted': false,
        '_sync_client_updated_at': localUpdatedAt - 1000,
        '_sync_updated_at': Timestamp.fromMillisecondsSinceEpoch(
          localUpdatedAt - 1000,
        ),
      });

      await sync.pullLibrary(uid);

      final storedRows = await rawDatabase.query(
        AppConstants.tableLibrary,
        where: 'key = ?',
        whereArgs: ['movie:404'],
        limit: 1,
      );
      final stored = MediaItem.fromJson(
        jsonDecode(storedRows.single['data']! as String)
            as Map<String, dynamic>,
      );

      expect(stored.title, 'Local Newer Movie');
      expect(stored.voteAverage, 9.2);

      final outboxRows = await rawDatabase.query(
        AppConstants.tableSyncOutbox,
        where: 'entity_id = ?',
        whereArgs: ['movie:404'],
      );
      expect(outboxRows, hasLength(1));
      expect(outboxRows.single['synced_at'], isNull);
    },
  );
}
