import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'constants.dart';

class ApiConfig {
  ApiConfig._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static String tmdbKey = AppConstants.tmdbApiKey;
  static String geminiKey = AppConstants.geminiApiKey;
  static String videoSourceBaseUrl = AppConstants.videoSourceBaseUrl;

  static Future<void> init() async {
    final storedTmdb = (await _storage.read(key: 'tmdb_api_key'))?.trim();
    final storedGemini = (await _storage.read(key: 'gemini_api_key'))?.trim();

    tmdbKey = storedTmdb?.isNotEmpty == true ? storedTmdb! : AppConstants.tmdbApiKey;
    geminiKey = storedGemini?.isNotEmpty == true ? storedGemini! : AppConstants.geminiApiKey;
    videoSourceBaseUrl = AppConstants.videoSourceBaseUrl;
  }

  static Future<void> save({String? tmdb, String? gemini}) async {
    if (tmdb != null) {
      final value = tmdb.trim();
      if (value.isEmpty) {
        await _storage.delete(key: 'tmdb_api_key');
        tmdbKey = AppConstants.tmdbApiKey;
      } else {
        await _storage.write(key: 'tmdb_api_key', value: value);
        tmdbKey = value;
      }
    }

    if (gemini != null) {
      final value = gemini.trim();
      if (value.isEmpty) {
        await _storage.delete(key: 'gemini_api_key');
        geminiKey = AppConstants.geminiApiKey;
      } else {
        await _storage.write(key: 'gemini_api_key', value: value);
        geminiKey = value;
      }
    }
  }
}
