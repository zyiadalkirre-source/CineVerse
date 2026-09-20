import 'package:flutter_test/flutter_test.dart';

import 'package:cineverse/models/media_item.dart';

void main() {
  test('MediaItem preserves favorites and episode progress in JSON', () {
    const item = MediaItem(
      id: 42,
      title: 'Test Show',
      overview: 'Overview',
      voteAverage: 8.0,
      mediaType: 'tv',
      seasons: 2,
      episodes: 20,
      isFavorite: true,
      lastWatchedSeconds: 125,
      lastWatchedSeason: 2,
      lastWatchedEpisode: 4,
      lastWatchedEpisodeName: 'Episode 4',
    );

    final restored = MediaItem.fromJson(item.toJson());

    expect(restored.id, 42);
    expect(restored.title, 'Test Show');
    expect(restored.mediaType, 'tv');
    expect(restored.isFavorite, isTrue);
    expect(restored.lastWatchedSeconds, 125);
    expect(restored.lastWatchedSeason, 2);
    expect(restored.lastWatchedEpisode, 4);
    expect(restored.lastWatchedEpisodeName, 'Episode 4');
  });

  test('MediaItem copyWith updates only requested fields', () {
    const item = MediaItem(id: 1, title: 'Old', overview: '', voteAverage: 0, mediaType: 'movie');
    final updated = item.copyWith(title: 'New', isFavorite: true);

    expect(updated.title, 'New');
    expect(updated.isFavorite, isTrue);
    expect(updated.id, 1);
    expect(updated.mediaType, 'movie');
  });
}