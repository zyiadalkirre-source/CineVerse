import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String _baseUrl = 'https://api.themoviedb.org/3';
  static const String _apiKey = 'YOUR_TMDB_API_KEY'; // سنضع المفتاح الخاص بك لاحقاً

  static Future<List<dynamic>> getTrendingMedia({
    String mediaType = 'all', 
    String timeWindow = 'day',
  }) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/trending/$mediaType/$timeWindow?api_key=$_apiKey'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['results'] ?? [];
    } else {
      throw Exception('Failed to load media data');
    }
  }
}
