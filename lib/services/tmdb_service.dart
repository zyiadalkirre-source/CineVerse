import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/api_config.dart';
import '../core/constants.dart';
import '../models/media_item.dart';
import '../models/watch_provider.dart';

class TmdbException implements Exception {
  const TmdbException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final String? code;

  @override
  String toString() => message;
}

class TmdbService {
  TmdbService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final String _base = AppConstants.tmdbBaseUrl;

  String get _apiKey => ApiConfig.tmdbKey.trim();

  void _checkApiKey() {
    if (_apiKey.isEmpty) {
      throw const TmdbException(
        'خدمة TMDB غير مهيأة حالياً. سيعمل التطبيق محلياً، ويمكن إضافة المفتاح من الإعدادات المتقدمة.',
        code: 'MISSING_API_KEY',
      );
    }
  }

  Future<Map<String, dynamic>> _get(String path, {Map<String, String> query = const {}}) async {
    _checkApiKey();
    final uri = Uri.parse('$_base$path').replace(queryParameters: {'api_key': _apiKey, ...query});

    late final http.Response response;
    try {
      response = await _client.get(uri).timeout(const Duration(seconds: 12));
    } on TimeoutException {
      throw const TmdbException('انتهت مهلة الاتصال بخدمة TMDB.', code: 'TIMEOUT');
    } on SocketException {
      throw const TmdbException('تعذر الاتصال بخدمة TMDB. تحقق من الإنترنت.', code: 'NETWORK');
    } on HttpException {
      throw const TmdbException('تعذر الاتصال بخدمة TMDB.', code: 'NETWORK');
    }

    switch (response.statusCode) {
      case 200:
      case 201:
        break;
      case 401:
        throw const TmdbException('مفتاح TMDB غير صالح أو تم إلغاؤه.', statusCode: 401, code: 'UNAUTHORIZED');
      case 404:
        throw const TmdbException('لم يتم العثور على المحتوى المطلوب في TMDB.', statusCode: 404, code: 'NOT_FOUND');
      case 429:
        throw const TmdbException('تم تجاوز حد طلبات TMDB مؤقتاً. حاول لاحقاً.', statusCode: 429, code: 'RATE_LIMIT');
      case 500:
      case 502:
      case 503:
        throw TmdbException('خدمة TMDB تواجه مشكلة مؤقتة (HTTP ${response.statusCode}).', statusCode: response.statusCode, code: 'SERVER_ERROR');
      default:
        throw TmdbException('تعذر إكمال طلب TMDB حالياً (HTTP ${response.statusCode}).', statusCode: response.statusCode, code: 'HTTP_ERROR');
    }

    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) throw const TmdbException('استجابة TMDB غير صالحة.', code: 'INVALID_RESPONSE');
      return Map<String, dynamic>.from(decoded);
    } on TmdbException {
      rethrow;
    } catch (_) {
      throw const TmdbException('تعذر قراءة استجابة TMDB.', code: 'INVALID_RESPONSE');
    }
  }

  Future<List<MediaItem>> search(String query, {String lang = 'ar'}) async {
    if (query.trim().isEmpty) return [];
    final data = await _get('/search/multi', query: {'query': query.trim(), 'language': lang, 'include_adult': 'false'});
    final results = data['results'];
    if (results is! List) return [];
    return results.whereType<Map>()
        .where((item) => item['media_type'] == 'movie' || item['media_type'] == 'tv')
        .map((item) => MediaItem.fromJson(Map<String, dynamic>.from(item))).toList();
  }

  Future<MediaItem> getDetails(int id, String type, {String lang = 'ar'}) async {
    _validateType(type);
    final data = await _get('/${type}/${id}', query: {'language': lang});
    var item = MediaItem.fromJson({...data, 'media_type': type});
    try {
      final credits = await _get('/${type}/${id}/credits', query: {'language': lang});
      final cast = credits['cast'] is List
          ? (credits['cast'] as List).whereType<Map>().take(15).map((value) => value['name']?.toString() ?? '').where((name) => name.isNotEmpty).toList()
          : <String>[];
      final directors = credits['crew'] is List
          ? (credits['crew'] as List).whereType<Map>().where((value) => value['job'] == 'Director').map((value) => value['name']?.toString() ?? '').where((name) => name.isNotEmpty).toList()
          : <String>[];
      item = item.copyWith(cast: cast, director: directors.isEmpty ? null : directors.first);
    } catch (_) {}
    try {
      final trailer = _firstYoutubeTrailer(await getVideos(id, type, lang: lang));
      if (trailer != null) item = item.copyWith(trailerKey: trailer['key']?.toString());
    } catch (_) {}
    return item;
  }

  Future<List<Map<String, dynamic>>> getVideos(int id, String type, {String? lang}) async {
    _validateType(type);
    final data = await _get('/${type}/${id}/videos', query: {if (lang != null) 'language': lang});
    return _mapResults(data['results']);
  }

  Future<List<Map<String, dynamic>>> getEpisodeVideos(int tvId, int season, int episode, {String? lang}) async {
    if (tvId <= 0 || season < 0 || episode <= 0) {
      throw const TmdbException('بيانات الحلقة غير صالحة.', code: 'INVALID_EPISODE');
    }
    final data = await _get('/tv/${tvId}/season/${season}/episode/${episode}/videos', query: {if (lang != null) 'language': lang});
    return _mapResults(data['results']);
  }

  Future<List<WatchProvider>> getWatchProviders(int id, String type, {String region = 'SY'}) async {
    _validateType(type);
    final data = await _get('/${type}/${id}/watch/providers');
    final results = data['results'];
    if (results is! Map) return [];
    final regionData = results[region];
    if (regionData is! Map) return [];

    final providers = <WatchProvider>[];
    void add(dynamic raw, String kind) {
      if (raw is! List) return;
      for (final value in raw.whereType<Map>()) {
        final providerId = (value['provider_id'] as num?)?.toInt();
        final name = value['provider_name']?.toString().trim();
        if (providerId == null || name == null || name.isEmpty) continue;
        providers.add(WatchProvider(
          id: providerId,
          name: name,
          type: kind,
          logoPath: value['logo_path']?.toString(),
          link: regionData['link']?.toString(),
        ));
      }
    }
    add(regionData['flatrate'], 'اشتراك');
    add(regionData['free'], 'مجاني');
    add(regionData['ads'], 'إعلانات');
    add(regionData['rent'], 'إيجار');
    add(regionData['buy'], 'شراء');

    final unique = <String, WatchProvider>{};
    for (final provider in providers) unique['${provider.id}:${provider.type}'] = provider;
    return unique.values.toList();
  }

  String? findYoutubeTrailerKey(List<Map<String, dynamic>> videos) => _firstYoutubeTrailer(videos)?['key']?.toString();

  Future<List<MediaItem>> getRecommendations(int id, String type, {String lang = 'ar'}) async {
    _validateType(type);
    final data = await _get('/${type}/${id}/recommendations', query: {'language': lang});
    final raw = data['results'];
    return raw is List
        ? raw.whereType<Map>().take(12).map((value) => MediaItem.fromJson({...Map<String, dynamic>.from(value), 'media_type': type})).toList()
        : [];
  }

  Future<List<MediaItem>> getTrending({String lang = 'ar'}) async {
    final data = await _get('/trending/all/week', query: {'language': lang});
    final raw = data['results'];
    return raw is List
        ? raw.whereType<Map>().where((value) => value['media_type'] == 'movie' || value['media_type'] == 'tv').take(20).map((value) => MediaItem.fromJson(Map<String, dynamic>.from(value))).toList()
        : [];
  }

  Future<List<MediaItem>> getTopRated({String type = 'movie', String lang = 'ar'}) async {
    _validateType(type);
    final data = await _get('/${type}/top_rated', query: {'language': lang});
    final raw = data['results'];
    return raw is List
        ? raw.whereType<Map>().take(20).map((value) => MediaItem.fromJson({...Map<String, dynamic>.from(value), 'media_type': type})).toList()
        : [];
  }

  Future<List<Map<String, dynamic>>> getTvEpisodes(int id, int season, {String lang = 'ar'}) async {
    final data = await _get('/tv/${id}/season/${season}', query: {'language': lang});
    return _mapResults(data['episodes']);
  }

  Future<List<MediaItem>> getLatestUpdates({String lang = 'ar'}) async {
    final results = <MediaItem>[];
    Future<void> load(String path, String type) async {
      try {
        final data = await _get('/$path', query: {'language': lang, 'page': '1'});
        final raw = data['results'];
        if (raw is List) {
          results.addAll(raw.whereType<Map>().map((value) => MediaItem.fromJson({...Map<String, dynamic>.from(value), 'media_type': type})));
        }
      } catch (_) {}
    }
    await load('movie/now_playing', 'movie');
    await load('tv/airing_today', 'tv');
    final unique = <String, MediaItem>{for (final item in results) '${item.mediaType}:${item.id}': item};
    final list = unique.values.toList()..sort((a, b) => b.voteAverage.compareTo(a.voteAverage));
    return list.take(30).toList();
  }

  List<Map<String, dynamic>> _mapResults(dynamic raw) => raw is List
      ? raw.whereType<Map>().map((value) => Map<String, dynamic>.from(value)).toList()
      : <Map<String, dynamic>>[];

  Map<String, dynamic>? _firstYoutubeTrailer(List<Map<String, dynamic>> videos) {
    Map<String, dynamic>? fallback;
    for (final video in videos) {
      final site = video['site']?.toString().toLowerCase();
      final key = video['key']?.toString().trim();
      if (site != 'youtube' || key == null || key.isEmpty) continue;
      fallback ??= video;
      if (video['type']?.toString().toLowerCase() == 'trailer') return video;
    }
    return fallback;
  }

  void _validateType(String type) {
    if (type != AppConstants.typeMovie && type != AppConstants.typeTv) {
      throw ArgumentError.value(type, 'type', 'TMDB type must be movie or tv');
    }
  }

  void dispose() => _client.close();
}
