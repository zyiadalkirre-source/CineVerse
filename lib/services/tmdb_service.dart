import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../core/api_config.dart';
import '../models/media_item.dart';

class TmdbService {
  String get _apiKey => ApiConfig.tmdbKey;
  final String _base = AppConstants.tmdbBaseUrl;

  void _checkApiKey() {
    if (_apiKey.trim().isEmpty) {
      throw StateError('TMDB API key is not configured. Build with --dart-define=TMDB_API_KEY=...');
    }
  }

  Future<List<MediaItem>> search(String query, {String lang = 'ar'}) async {
    if (query.trim().isEmpty) return [];
    _checkApiKey();
    final url = Uri.parse('$_base/search/multi').replace(queryParameters: {
      'api_key': _apiKey,
      'query': query.trim(),
      'language': lang,
    });
    final res = await http.get(url);
    if (res.statusCode != 200) throw Exception('Search failed: ${res.statusCode}');
    final data = json.decode(utf8.decode(res.bodyBytes));
    final results = data['results'];
    if (results is! List) return [];
    return results
        .whereType<Map>()
        .where((i) => i['media_type'] != 'person')
        .map((i) => MediaItem.fromJson(Map<String, dynamic>.from(i)))
        .toList();
  }

  Future<MediaItem> getDetails(int id, String type, {String lang = 'ar'}) async {
    _checkApiKey();
    if (type != 'movie' && type != 'tv') {
      throw ArgumentError.value(type, 'type', 'TMDB type must be movie or tv');
    }

    final url = Uri.parse('$_base/$type/$id').replace(queryParameters: {
      'api_key': _apiKey,
      'language': lang,
    });
    final res = await http.get(url);
    if (res.statusCode != 200) throw Exception('Details failed: ${res.statusCode}');
    final data = Map<String, dynamic>.from(json.decode(utf8.decode(res.bodyBytes)));
    var item = MediaItem.fromJson({...data, 'media_type': type});

    try {
      final creditsUrl = Uri.parse('$_base/$type/$id/credits').replace(queryParameters: {'api_key': _apiKey});
      final cRes = await http.get(creditsUrl);
      if (cRes.statusCode == 200) {
        final credits = Map<String, dynamic>.from(json.decode(utf8.decode(cRes.bodyBytes)));
        final rawCast = credits['cast'];
        final cast = rawCast is List
            ? rawCast.take(15).whereType<Map>().map((c) => c['name']?.toString() ?? '').where((n) => n.isNotEmpty).toList()
            : <String>[];
        final rawCrew = credits['crew'];
        final directors = rawCrew is List
            ? rawCrew.whereType<Map>().where((c) => c['job'] == 'Director').map((c) => c['name']?.toString() ?? '').where((n) => n.isNotEmpty).toList()
            : <String>[];
        item = item.copyWith(cast: cast, director: directors.isNotEmpty ? directors.first : null);
      }
    } catch (_) {}

    try {
      final vUrl = Uri.parse('$_base/$type/$id/videos').replace(queryParameters: {'api_key': _apiKey});
      final vRes = await http.get(vUrl);
      if (vRes.statusCode == 200) {
        final vids = Map<String, dynamic>.from(json.decode(utf8.decode(vRes.bodyBytes)));
        final results = vids['results'];
        if (results is List) {
          final trailers = results.whereType<Map>().where((v) =>
              v['type'] == 'Trailer' && v['site'] == 'YouTube' && (v['key']?.toString().isNotEmpty ?? false));
          if (trailers.isNotEmpty) {
            item = item.copyWith(trailerKey: trailers.first['key'].toString());
          }
        }
      }
    } catch (_) {}

    return item;
  }

  Future<List<MediaItem>> getRecommendations(int id, String type, {String lang = 'ar'}) async {
    _checkApiKey();
    final url = Uri.parse('$_base/$type/$id/recommendations').replace(queryParameters: {
      'api_key': _apiKey, 'language': lang,
    });
    final res = await http.get(url);
    if (res.statusCode != 200) return [];
    final data = json.decode(utf8.decode(res.bodyBytes));
    final results = data['results'];
    if (results is! List) return [];
    return results.take(12).whereType<Map>().map((i) => MediaItem.fromJson(Map<String, dynamic>.from(i))).toList();
  }

  Future<List<MediaItem>> getTrending({String lang = 'ar'}) async {
    _checkApiKey();
    final url = Uri.parse('$_base/trending/all/week').replace(queryParameters: {
      'api_key': _apiKey, 'language': lang,
    });
    final res = await http.get(url);
    if (res.statusCode != 200) return [];
    final data = json.decode(utf8.decode(res.bodyBytes));
    final results = data['results'];
    if (results is! List) return [];
    return results.take(20).whereType<Map>().where((i) => i['media_type'] != 'person')
        .map((i) => MediaItem.fromJson(Map<String, dynamic>.from(i))).toList();
  }

  Future<List<MediaItem>> getTopRated({String type = 'movie', String lang = 'ar'}) async {
    _checkApiKey();
    if (type != 'movie' && type != 'tv') throw ArgumentError.value(type, 'type');
    final url = Uri.parse('$_base/$type/top_rated').replace(queryParameters: {
      'api_key': _apiKey, 'language': lang,
    });
    final res = await http.get(url);
    if (res.statusCode != 200) return [];
    final data = json.decode(utf8.decode(res.bodyBytes));
    final results = data['results'];
    if (results is! List) return [];
    return results.take(20).whereType<Map>().map((i) =>
      MediaItem.fromJson({...Map<String, dynamic>.from(i), 'media_type': type})
    ).toList();
  }
  Future<List<Map<String, dynamic>>> getTvEpisodes(int id, int season, {String lang = 'ar'}) async {
    _checkApiKey();
    final url = Uri.parse('$_base/tv/$id/season/$season').replace(queryParameters: {
      'api_key': _apiKey,
      'language': lang,
    });
    final res = await http.get(url);
    if (res.statusCode != 200) return [];
    final data = json.decode(utf8.decode(res.bodyBytes));
    final raw = data['episodes'];
    if (raw is! List) return [];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<List<MediaItem>> getLatestUpdates({String lang = 'ar'}) async {
    _checkApiKey();
    final results = <MediaItem>[];

    Future<void> load(String path, String type) async {
      try {
        final url = Uri.parse(_base + '/' + path).replace(queryParameters: {
          'api_key': _apiKey,
          'language': lang,
          'page': '1',
        });
        final res = await http.get(url);
        if (res.statusCode != 200) return;
        final data = json.decode(utf8.decode(res.bodyBytes));
        final raw = data['results'];
        if (raw is List) {
          results.addAll(raw.whereType<Map>().map((i) => MediaItem.fromJson({
            ...Map<String, dynamic>.from(i),
            'media_type': type,
          })));
        }
      } catch (_) {}
    }

    await load('movie/now_playing', 'movie');
    await load('tv/airing_today', 'tv');

    final unique = <String, MediaItem>{};
    for (final item in results) {
      unique[item.mediaType + ':' + item.id.toString()] = item;
    }
    final list = unique.values.toList()
      ..sort((a, b) => b.voteAverage.compareTo(a.voteAverage));
    return list.take(30).toList();
  }

}
