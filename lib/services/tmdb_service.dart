import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/api_config.dart';
import '../core/constants.dart';
import '../models/media_item.dart';
import '../models/watch_provider.dart';

class TmdbService {
  String get _apiKey => ApiConfig.tmdbKey.trim();
  final String _base = AppConstants.tmdbBaseUrl;

  void _checkApiKey() {
    if (_apiKey.isEmpty) {
      throw StateError(
        'TMDB غير مهيأ في نسخة التطبيق. يجب أن يزوّد بناء التطبيق بالمفتاح الافتراضي عبر TMDB_API_KEY.',
      );
    }
  }

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, String> query = const {},
  }) async {
    _checkApiKey();

    final uri = Uri.parse('$_base$path').replace(
      queryParameters: {
        'api_key': _apiKey,
        ...query,
      },
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 12));

    if (response.statusCode == 401) {
      throw StateError('مفتاح TMDB الافتراضي غير صالح أو منتهي.');
    }
    if (response.statusCode == 429) {
      throw StateError('تم تجاوز حد طلبات TMDB مؤقتاً. حاول مرة أخرى بعد قليل.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('تعذر الاتصال بخدمة TMDB حالياً.');
    }

    final decoded = json.decode(utf8.decode(response.bodyBytes));
    if (decoded is! Map) {
      throw StateError('استجابة TMDB غير صالحة.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  Future<List<MediaItem>> search(String query, {String lang = 'ar'}) async {
    if (query.trim().isEmpty) return [];

    final data = await _get(
      '/search/multi',
      query: {
        'query': query.trim(),
        'language': lang,
        'include_adult': 'false',
      },
    );

    final results = data['results'];
    if (results is! List) return [];

    return results
        .whereType<Map>()
        .where((i) => i['media_type'] != 'person')
        .map((i) => MediaItem.fromJson(Map<String, dynamic>.from(i)))
        .toList();
  }

  Future<MediaItem> getDetails(
    int id,
    String type, {
    String lang = 'ar',
  }) async {
    if (type != 'movie' && type != 'tv') {
      throw ArgumentError.value(
        type,
        'type',
        'TMDB type must be movie or tv',
      );
    }

    final data = await _get(
      '/$type/$id',
      query: {'language': lang},
    );

    var item = MediaItem.fromJson({
      ...data,
      'media_type': type,
    });

    try {
      final credits = await _get(
        '/$type/$id/credits',
        query: {'language': lang},
      );
      final rawCast = credits['cast'];
      final cast = rawCast is List
          ? rawCast
              .take(15)
              .whereType<Map>()
              .map((c) => c['name']?.toString() ?? '')
              .where((n) => n.isNotEmpty)
              .toList()
          : <String>[];

      final rawCrew = credits['crew'];
      final directors = rawCrew is List
          ? rawCrew
              .whereType<Map>()
              .where((c) => c['job'] == 'Director')
              .map((c) => c['name']?.toString() ?? '')
              .where((n) => n.isNotEmpty)
              .toList()
          : <String>[];

      item = item.copyWith(
        cast: cast,
        director: directors.isNotEmpty ? directors.first : null,
      );
    } catch (_) {}

    try {
      final videos = await getVideos(id, type);
      final trailer = _firstYoutubeTrailer(videos);
      if (trailer != null) {
        item = item.copyWith(trailerKey: trailer['key']?.toString());
      }
    } catch (_) {}

    return item;
  }

  Future<List<Map<String, dynamic>>> getVideos(
    int id,
    String type, {
    String? lang,
  }) async {
    if (type != 'movie' && type != 'tv') {
      throw ArgumentError.value(type, 'type');
    }

    final data = await _get(
      '/$type/$id/videos',
      query: {
        if (lang != null) 'language': lang,
      },
    );
    final results = data['results'];
    if (results is! List) return [];

    return results
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getEpisodeVideos(
    int tvId,
    int season,
    int episode, {
    String? lang,
  }) async {
    final data = await _get(
      '/tv/$tvId/season/$season/episode/$episode/videos',
      query: {
        if (lang != null) 'language': lang,
      },
    );
    final results = data['results'];
    if (results is! List) return [];

    return results
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Map<String, dynamic>? _firstYoutubeTrailer(
    List<Map<String, dynamic>> videos,
  ) {
    for (final video in videos) {
      final type = video['type']?.toString().toLowerCase();
      final site = video['site']?.toString().toLowerCase();
      final key = video['key']?.toString().trim();

      if (type == 'trailer' &&
          site == 'youtube' &&
          key != null &&
          key.isNotEmpty) {
        return video;
      }
    }

    for (final video in videos) {
      final site = video['site']?.toString().toLowerCase();
      final key = video['key']?.toString().trim();
      if (site == 'youtube' && key != null && key.isNotEmpty) {
        return video;
      }
    }

    return null;
  }

  String? findYoutubeTrailerKey(List<Map<String, dynamic>> videos) =>
      _firstYoutubeTrailer(videos)?['key']?.toString();

  Future<List<WatchProvider>> getWatchProviders(
    int id,
    String type, {
    String region = 'SY',
  }) async {
    if (type != 'movie' && type != 'tv') {
      throw ArgumentError.value(type, 'type');
    }

    final data = await _get('/$type/$id/watch/providers');
    final results = data['results'];
    if (results is! Map) return [];

    final regionData = results[region];
    if (regionData is! Map) return [];

    final providers = <WatchProvider>[];

    void addProviders(dynamic raw, String kind) {
      if (raw is! List) return;
      for (final value in raw.whereType<Map>()) {
        final providerId = (value['provider_id'] as num?)?.toInt();
        final name = value['provider_name']?.toString().trim();
        if (providerId == null || name == null || name.isEmpty) continue;

        providers.add(
          WatchProvider(
            id: providerId,
            name: name,
            logoPath: value['logo_path']?.toString(),
            type: kind,
          ),
        );
      }
    }

    addProviders(regionData['flatrate'], 'اشتراك');
    addProviders(regionData['free'], 'مجاني');
    addProviders(regionData['ads'], 'إعلانات');
    addProviders(regionData['rent'], 'إيجار');
    addProviders(regionData['buy'], 'شراء');

    final unique = <String, WatchProvider>{};
    for (final provider in providers) {
      unique['${provider.id}:${provider.type}'] = provider;
    }
    return unique.values.toList();
  }

  Future<List<MediaItem>> getRecommendations(
    int id,
    String type, {
    String lang = 'ar',
  }) async {
    final data = await _get(
      '/$type/$id/recommendations',
      query: {'language': lang},
    );
    final results = data['results'];
    if (results is! List) return [];

    return results
        .take(12)
        .whereType<Map>()
        .map(
          (i) => MediaItem.fromJson(
            Map<String, dynamic>.from(i),
          ),
        )
        .toList();
  }

  Future<List<MediaItem>> getTrending({String lang = 'ar'}) async {
    final data = await _get(
      '/trending/all/week',
      query: {'language': lang},
    );
    final results = data['results'];
    if (results is! List) return [];

    return results
        .take(20)
        .whereType<Map>()
        .where((i) => i['media_type'] != 'person')
        .map(
          (i) => MediaItem.fromJson(
            Map<String, dynamic>.from(i),
          ),
        )
        .toList();
  }

  Future<List<MediaItem>> getTopRated({
    String type = 'movie',
    String lang = 'ar',
  }) async {
    if (type != 'movie' && type != 'tv') {
      throw ArgumentError.value(type, 'type');
    }

    final data = await _get(
      '/$type/top_rated',
      query: {'language': lang},
    );
    final results = data['results'];
    if (results is! List) return [];

    return results
        .take(20)
        .whereType<Map>()
        .map(
          (i) => MediaItem.fromJson({
            ...Map<String, dynamic>.from(i),
            'media_type': type,
          }),
        )
        .toList();
  }

  Future<List<Map<String, dynamic>>> getTvEpisodes(
    int id,
    int season, {
    String lang = 'ar',
  }) async {
    final data = await _get(
      '/tv/$id/season/$season',
      query: {'language': lang},
    );
    final raw = data['episodes'];
    if (raw is! List) return [];

    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<List<MediaItem>> getLatestUpdates({String lang = 'ar'}) async {
    final results = <MediaItem>[];

    Future<void> load(String path, String type) async {
      try {
        final data = await _get(
          '/$path',
          query: {
            'language': lang,
            'page': '1',
          },
        );
        final raw = data['results'];
        if (raw is List) {
          results.addAll(
            raw.whereType<Map>().map(
              (i) => MediaItem.fromJson({
                ...Map<String, dynamic>.from(i),
                'media_type': type,
              }),
            ),
          );
        }
      } catch (_) {}
    }

    await load('movie/now_playing', 'movie');
    await load('tv/airing_today', 'tv');

    final unique = <String, MediaItem>{};
    for (final item in results) {
      unique['${item.mediaType}:${item.id}'] = item;
    }

    final list = unique.values.toList()
      ..sort((a, b) => b.voteAverage.compareTo(a.voteAverage));

    return list.take(30).toList();
  }
}
