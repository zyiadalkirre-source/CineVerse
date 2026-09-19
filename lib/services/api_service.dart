import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String _baseUrl = 'https://api.themoviedb.org/3';
  static const String _apiKey = 'YOUR_TMDB_API_KEY'; // سنضع المفتاح الخاص بك لاحقاً

  static Future<List<dynamic>> getTrendingMedia({
    String mediaType = 'all', 
    String timeWindow = 'day',
  }) async {
    if (_apiKey == 'YOUR_TMDB_API_KEY') {
      throw StateError(
        'TMDB API key is not configured. Replace YOUR_TMDB_API_KEY '
        'with a valid key before requesting media data.',
      );
    }

    final uri = Uri.parse('$_baseUrl/trending/$mediaType/$timeWindow').replace(
      queryParameters: {'api_key': _apiKey},
    );
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['results'] ?? [];
    } else {
      throw Exception('Failed to load media data (' + response.statusCode.toString() + ').');
    }
  }
}
