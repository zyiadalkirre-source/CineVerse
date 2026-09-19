import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/api_config.dart';
import '../core/constants.dart';

class ApiService {
  static Future<List<dynamic>> getTrendingMedia({String mediaType='all',String timeWindow='day'}) async {
    final key=ApiConfig.tmdbKey;
    if(key.trim().isEmpty) throw StateError('TMDB API key is not configured.');
    final uri=Uri.parse('\${AppConstants.tmdbBaseUrl}/trending/\$mediaType/\$timeWindow').replace(queryParameters:{'api_key':key});
    final response=await http.get(uri);
    if(response.statusCode!=200) throw Exception('Failed to load media data (\${response.statusCode}).');
    final data=json.decode(utf8.decode(response.bodyBytes));
    return data is Map && data['results'] is List ? List<dynamic>.from(data['results']) : <dynamic>[];
  }
}
