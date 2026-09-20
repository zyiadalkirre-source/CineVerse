import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/api_config.dart';
import '../models/media_item.dart';

class VideoSourceService {
  VideoSourceService._();
  static final instance = VideoSourceService._();

  Future<String?> resolve({
    required MediaItem item,
    required int season,
    required int episode,
  }) async {
    final base = ApiConfig.videoSourceBaseUrl.trim();
    if (base.isEmpty) return null;

    try {
      final parsed = Uri.parse(base);
      final basePath = parsed.path.replaceFirst(RegExp(r'/+$'), '');
      final uri = parsed.replace(
        path: basePath + '/resolve',
        queryParameters: {
          'media_id': item.id.toString(),
          'media_type': item.mediaType,
          'season': season.toString(),
          'episode': episode.toString(),
        },
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return null;

      final decoded = json.decode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) return null;

      for (final key in const ['video_url', 'stream_url', 'url']) {
        final value = decoded[key]?.toString().trim();
        if (value != null && value.isNotEmpty) return value;
      }
    } catch (_) {}

    return null;
  }
}