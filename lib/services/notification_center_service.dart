import '../models/media_item.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/tmdb_service.dart';

class NotificationCenterService {
  NotificationCenterService._();

  static final _database = DatabaseService.instance;

  static Future<int> checkForNewEpisodes({
    required List<MediaItem> favoriteShows,
    required TmdbService tmdb,
    required Future<void> Function(MediaItem item) updateItem,
  }) async {
    var created = 0;

    for (final item in favoriteShows.where((x) => x.mediaType == 'tv')) {
      try {
        final latest = await tmdb.getDetails(item.id, item.mediaType, lang: 'ar');
        final oldCount = item.episodes ?? 0;
        final newCount = latest.episodes ?? oldCount;

        if (newCount > oldCount) {
          final added = newCount - oldCount;
          final body = added == 1
              ? 'نزلت حلقة جديدة لمسلسل \${item.title}.'
              : 'نزلت \$added حلقات جديدة لمسلسل \${item.title}.';

          await _database.addNotification(
            title: 'حلقة جديدة 🎬',
            body: body,
          );

          await NotificationService.showNotification(
            id: item.id,
            title: 'حلقة جديدة في \${item.title}',
            body: body,
          );

          await updateItem(
            item.copyWith(
              episodes: newCount,
              seasons: latest.seasons ?? item.seasons,
            ),
          );

          created++;
        }
      } catch (_) {}
    }

    return created;
  }
}
