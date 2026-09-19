import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../models/media_item.dart';

class JikanService {
  final String _base = AppConstants.jikanBaseUrl;

  Future<List<MediaItem>> searchAnime(String query) async {
    if (query.trim().isEmpty) return [];
    final url = Uri.parse('$_base/anime').replace(queryParameters: {
      'q': query.trim(), 'limit': '15', 'sfw': '',
    });
    final res = await http.get(url);
    if (res.statusCode != 200) return [];
    return _parseList(json.decode(utf8.decode(res.bodyBytes)));
  }

  Future<List<MediaItem>> seasonalNow() async {
    final res = await http.get(Uri.parse('$_base/seasons/now?limit=20&sfw'));
    if (res.statusCode != 200) return [];
    return _parseList(json.decode(utf8.decode(res.bodyBytes)));
  }

  Future<List<MediaItem>> topAnime() async {
    final res = await http.get(Uri.parse('$_base/top/anime?limit=25&sfw'));
    if (res.statusCode != 200) return [];
    return _parseList(json.decode(utf8.decode(res.bodyBytes)));
  }

  Future<Map<String, dynamic>> getAnimeFull(int malId) async {
    final res = await http.get(Uri.parse('$_base/anime/$malId/full'));
    if (res.statusCode != 200) return {};
    final decoded = json.decode(utf8.decode(res.bodyBytes));
    return decoded is Map && decoded['data'] is Map
        ? Map<String, dynamic>.from(decoded['data'])
        : {};
  }

  Future<List<Map<String, dynamic>>> getEpisodes(int malId, {int page = 1}) async {
    final res = await http.get(Uri.parse('$_base/anime/$malId/episodes?page=$page'));
    if (res.statusCode != 200) return [];
    final decoded = json.decode(utf8.decode(res.bodyBytes));
    final data = decoded is Map ? decoded['data'] : null;
    return data is List
        ? data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : [];
  }

  List<MediaItem> _parseList(dynamic decoded) {
    final data = decoded is Map ? decoded['data'] : null;
    return data is List
        ? data.whereType<Map>().map((j) => _fromJikan(Map<String, dynamic>.from(j))).toList()
        : [];
  }

  MediaItem _fromJikan(Map<String, dynamic> j) {
    final images = j['images'] is Map ? j['images']['jpg'] : null;
    final genres = <String>[];
    for (final g in (j['genres'] is List ? j['genres'] : const [])) {
      if (g is Map && g['name'] != null) genres.add(g['name'].toString());
    }
    for (final t in (j['themes'] is List ? j['themes'] : const [])) {
      if (t is Map && t['name'] != null) genres.add(t['name'].toString());
    }
    final aired = j['aired'] is Map ? j['aired']['from']?.toString() ?? '' : '';
    final releaseDate = aired.length >= 10 ? aired.substring(0, 10) : '';
    return MediaItem(
      id: (j['mal_id'] as num?)?.toInt() ?? 0,
      title: (j['title'] ?? j['title_english'] ?? 'Unknown').toString(),
      originalTitle: j['title_japanese']?.toString(),
      posterPath: images is Map ? images['large_image_url']?.toString() : null,
      backdropPath: images is Map ? images['large_image_url']?.toString() : null,
      overview: (j['synopsis'] ?? '').toString(),
      voteAverage: (j['score'] as num?)?.toDouble() ?? 0,
      voteCount: (j['scored_by'] as num?)?.toInt() ?? 0,
      releaseDate: releaseDate,
      mediaType: AppConstants.typeAnime,
      genres: genres,
      episodes: (j['episodes'] as num?)?.toInt(),
      runtime: j['duration'] != null ? _parseDuration(j['duration'].toString()) : null,
    );
  }

  int? _parseDuration(String d) {
    final match = RegExp(r'(\d+)').firstMatch(d);
    return match == null ? null : int.tryParse(match.group(1)!);
  }
}
