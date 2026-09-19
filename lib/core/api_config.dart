import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'constants.dart';

class ApiConfig {
  ApiConfig._();
  static const _storage = FlutterSecureStorage();
  static String tmdbKey = AppConstants.tmdbApiKey;
  static String geminiKey = AppConstants.geminiApiKey;

  static Future<void> init() async {
    tmdbKey = await _storage.read(key: 'tmdb_api_key') ?? AppConstants.tmdbApiKey;
    geminiKey = await _storage.read(key: 'gemini_api_key') ?? AppConstants.geminiApiKey;
  }

  static Future<void> save({String? tmdb, String? gemini}) async {
    if (tmdb != null) {
      tmdbKey = tmdb.trim();
      if (tmdbKey.isEmpty) await _storage.delete(key: 'tmdb_api_key');
      else await _storage.write(key: 'tmdb_api_key', value: tmdbKey);
    }
    if (gemini != null) {
      geminiKey = gemini.trim();
      if (geminiKey.isEmpty) await _storage.delete(key: 'gemini_api_key');
      else await _storage.write(key: 'gemini_api_key', value: geminiKey);
    }
  }
}