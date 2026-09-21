import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:cineverse/core/constants.dart';
import 'package:cineverse/models/media_item.dart';
import 'package:cineverse/services/database_service.dart';

void main() {
  late Database rawDb;
  late DatabaseService database;

  setUp(() async {
    sqfliteFfiInit();
    rawDb = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: AppConstants.dbVersion,
        onCreate: (db, version) =>
            DatabaseService.createSchemaForTest(db),
      ),
    );
    database = DatabaseService.forTest(rawDb);
  });

  tearDown(() async {
    await database.close();
  });

  MediaItem makeItem(
    int id,
    String mediaType,
  ) {
    return MediaItem(
      id: id,
      title: mediaType + ' ' + id.toString(),
      overview: 'Test item',
      mediaType: mediaType,
      voteAverage: 7.0,
    );
  }

  test(
    'prunes expired cache while preserving the matching user library item',
    () async {
      final old = DateTime.now().subtract(
        const Duration(days: 8),
      ).millisecondsSinceEpoch;

      final movie = makeItem(999, AppConstants.typeMovie);
      await database.saveMedia(
        movie,
        enqueueSync: false,
      );

      await rawDb.insert(
        AppConstants.tableMediaCache,
        {
          'id': 999,
          'media_type': AppConstants.typeMovie,
          'json_data': '{}',
          'cached_at': old,
        },
      );

      await rawDb.insert(
        AppConstants.tableMediaCache,
        {
          'id': 999,
          'media_type': AppConstants.typeAnime,
          'json_data': '{}',
          'cached_at': old,
        },
      );

      await rawDb.insert(
        AppConstants.tableMediaCache,
        {
          'id': 1000,
          'media_type': AppConstants.typeMovie,
          'json_data': '{}',
          'cached_at': old,
        },
      );

      await rawDb.insert(
        AppConstants.tableTrendingCache,
        {
          'category_key': 'old-category',
          'media_ids_json': '[]',
          'cached_at': old,
        },
      );

      final deleted = await database.pruneExpiredCache(
        maxAge: const Duration(days: 7),
      );

      expect(deleted, 2);

      final preserved = await rawDb.query(
        AppConstants.tableMediaCache,
        where: 'id = ? AND media_type = ?',
        whereArgs: [999, AppConstants.typeMovie],
      );
      expect(preserved, hasLength(1));

      final deletedAnime = await rawDb.query(
        AppConstants.tableMediaCache,
        where: 'id = ? AND media_type = ?',
        whereArgs: [999, AppConstants.typeAnime],
      );
      expect(deletedAnime, isEmpty);

      final deletedMovie = await rawDb.query(
        AppConstants.tableMediaCache,
        where: 'id = ? AND media_type = ?',
        whereArgs: [1000, AppConstants.typeMovie],
      );
      expect(deletedMovie, isEmpty);

      final trending = await rawDb.query(
        AppConstants.tableTrendingCache,
        where: 'category_key = ?',
        whereArgs: ['old-category'],
      );
      expect(trending, isEmpty);
    },
  );
}
