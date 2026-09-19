/// Constants used across CineVerse.
class AppConstants {
  // API keys are read from --dart-define and are never hard-coded in source.
  static const String tmdbApiKey = String.fromEnvironment('TMDB_API_KEY');
  static const String geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

  static const String tmdbBaseUrl = 'https://api.themoviedb.org/3';
  static const String tmdbImageW500 = 'https://image.tmdb.org/t/p/w500';
  static const String tmdbImageOriginal = 'https://image.tmdb.org/t/p/original';
  static const String jikanBaseUrl = 'https://api.jikan.moe/v4';

  static const String statusWatched = 'watched';
  static const String statusWatching = 'watching';
  static const String statusNotWatched = 'not_watched';
  static const String statusDropped = 'dropped';
  static const String statusOnHold = 'on_hold';

  static const String typeMovie = 'movie';
  static const String typeTv = 'tv';
  static const String typeAnime = 'anime';

  static const String geminiModel = 'gemini-2.5-flash';
  static const String geminiVisionModel = 'gemini-2.5-flash';

  static const String dbName = 'cineverse.db';
  static const int dbVersion = 1;
  static const String tableLibrary = 'library';
  static const String tableChat = 'chat_history';
  static const String tableSearchHistory = 'search_history';
}

class AppColors {
  static const int primary = 0xFF7C4DFF;
  static const int secondary = 0xFF00E5FF;
  static const int watched = 0xFF4CAF50;
  static const int watching = 0xFFFF9800;
  static const int notWatched = 0xFF9E9E9E;
  static const int dropped = 0xFFE53935;
  static const int onHold = 0xFF9C27B0;
  static const int darkBg = 0xFF0F0F1A;
  static const int darkCard = 0xFF1A1A2E;
  static const int lightBg = 0xFFF5F5FA;
  static const int lightCard = 0xFFFFFFFF;
}
