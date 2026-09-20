import 'package:sqflite/sqflite.dart';

class ContentCacheSchema {
  ContentCacheSchema._();

  static const String mediaCacheTable = 'media_cache';
  static const String trendingCacheTable = 'trending_cache';

  static const String createMediaCache = '''
CREATE TABLE $mediaCacheTable (
  id INTEGER NOT NULL,
  media_type TEXT NOT NULL,
  json_data TEXT NOT NULL,
  cached_at INTEGER NOT NULL,
  PRIMARY KEY (id, media_type)
)
''';

  static const String createTrendingCache = '''
CREATE TABLE $trendingCacheTable (
  category_key TEXT PRIMARY KEY,
  media_ids_json TEXT NOT NULL,
  cached_at INTEGER NOT NULL
)
''';

  static const String createMediaCacheIndex = '''
CREATE INDEX IF NOT EXISTS idx_media_cache_cached_at
ON $mediaCacheTable(cached_at)
''';

  static const String createTrendingCacheIndex = '''
CREATE INDEX IF NOT EXISTS idx_trending_cache_cached_at
ON $trendingCacheTable(cached_at)
''';

  static Future<void> create(Database db) async {
    await db.execute(createMediaCache);
    await db.execute(createTrendingCache);
    await db.execute(createMediaCacheIndex);
    await db.execute(createTrendingCacheIndex);
  }
}
