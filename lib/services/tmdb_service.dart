import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../models/media_item.dart';

class TmdbService {
  final String _apiKey = AppConstants.tmdbApiKey;
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
}
