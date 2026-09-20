import 'package:flutter/foundation.dart';
import '../core/constants.dart';
import '../models/media_item.dart';
import '../models/user_stats.dart';
import '../services/database_service.dart';
import '../services/tmdb_service.dart';
import '../services/jikan_service.dart';
import '../services/notification_center_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MediaProvider extends ChangeNotifier {
  final TmdbService tmdb = TmdbService();
  final JikanService jikan = JikanService();
  final DatabaseService database = DatabaseService.instance;
  List<MediaItem> _library = [];
  bool loading = false;
  String? error;
  String? lastCorrectedQuery;

  List<MediaItem> get library => List.unmodifiable(_library);

  MediaProvider() { _load(); }

  Future<void> _load() async {
    try {
      _library = await database.getLibrary();
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('notifyNewEpisodes') == true) {
        await NotificationCenterService.checkForNewEpisodes(
          favoriteShows: _library.where((x) => x.isFavorite && x.mediaType == AppConstants.typeTv).toList(),
          tmdb: tmdb,
          updateItem: upsert,
        );
      }
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();
  }

  Future<void> upsert(MediaItem item) async {
    final i = _library.indexWhere((x) => x.id == item.id && x.mediaType == item.mediaType);
    if (i >= 0) {
      _library[i] = item;
    } else {
      _library.add(item);
    }
    await database.saveMedia(item);
    notifyListeners();
  }

  Future<void> setStatus(MediaItem item, String status) async => upsert(item.copyWith(watchStatus: status));
  Future<void> toggleFavorite(MediaItem item) async => upsert(item.copyWith(isFavorite: !item.isFavorite));
  Future<void> saveWatchProgress(MediaItem item, {required int seconds, int? season, int? episode, String? episodeName, int durationSeconds = 0}) async {
    if (season != null && episode != null) {
      await database.saveEpisodeProgress(
        mediaId: item.id,
        mediaType: item.mediaType,
        season: season,
        episode: episode,
        positionSeconds: seconds,
        durationSeconds: durationSeconds,
        episodeName: episodeName ?? '',
      );
    }
    await upsert(item.copyWith(
      lastWatchedSeconds: seconds,
      lastWatchedSeason: season,
      lastWatchedEpisode: episode,
      lastWatchedEpisodeName: episodeName,
      watchStatus: seconds > 0 ? AppConstants.statusWatching : item.watchStatus,
    ));
  }

  Future<Map<String, dynamic>?> getEpisodeProgress({required MediaItem item, required int season, required int episode}) {
    return database.getEpisodeProgress(mediaId: item.id, mediaType: item.mediaType, season: season, episode: episode);
  }

  Future<List<Map<String, dynamic>>> episodeHistory({int limit = 50}) => database.getEpisodeHistory(limit: limit);

  Future<void> remove(MediaItem item) async {
    _library.removeWhere((x) => x.id == item.id && x.mediaType == item.mediaType);
    await database.deleteMedia(item);
    notifyListeners();
  }
  Future<void> setRating(MediaItem item, double? rating) async => upsert(item.copyWith(userRating: rating));
  Future<void> setNotes(MediaItem item, String notes) async => upsert(item.copyWith(notes: notes));

  Future<void> mergeCloudLibrary(List<MediaItem> items) async {
    for (final item in items) {
      final i = _library.indexWhere((x) => x.id == item.id && x.mediaType == item.mediaType);
      if (i >= 0) _library[i] = item; else _library.add(item);
      await database.saveMedia(item);
    }
    notifyListeners();
  }

  Future<void> clearLibrary() async {
    _library = [];
    await database.deleteLibrary();
    notifyListeners();
  }

  MediaItem? getById(int id, String type) {
    for (final x in _library) {
      if (x.id == id && x.mediaType == type) return x;
    }
    return null;
  }

  static const _popularTitles = <String>[
    'Lost', 'Breaking Bad', 'Better Call Saul', 'Stranger Things',
    'The Last of Us', 'Game of Thrones', 'The Walking Dead', 'Dark',
    'Prison Break', 'The Boys', 'Peaky Blinders', 'Sherlock',
    'Money Heist', 'Wednesday', 'House of the Dragon', 'Black Mirror',
    'The Office', 'Friends', 'The Sopranos', 'Dexter', 'Lucifer',
    'Narcos', 'Chernobyl', 'Mr. Robot', 'You', 'Manifest',
    'One Piece', 'Attack on Titan', 'Death Note', 'Demon Slayer',
  ];

  int _distance(String a, String b) {
    final x = a.toLowerCase();
    final y = b.toLowerCase();
    final prev = List<int>.generate(y.length + 1, (i) => i);
    for (var i = 0; i < x.length; i++) {
      var left = i + 1;
      final next = List<int>.filled(y.length + 1, 0);
      next[0] = left;
      for (var j = 0; j < y.length; j++) {
        final cost = x.codeUnitAt(i) == y.codeUnitAt(j) ? 0 : 1;
        next[j + 1] = [next[j] + 1, prev[j + 1] + 1, prev[j] + cost].reduce((a, b) => a < b ? a : b);
      }
      for (var j = 0; j <= y.length; j++) prev[j] = next[j];
    }
    return prev[y.length];
  }

  String? _correctQuery(String query) {
    final q = query.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), '').trim();
    if (q.isEmpty) return null;
    String? best;
    var bestScore = double.infinity;
    for (final title in _popularTitles) {
      final t = title.toLowerCase();
      final distance = _distance(q, t);
      final score = distance / (q.length > t.length ? q.length : t.length);
      if (score < bestScore) {
        bestScore = score;
        best = title;
      }
    }
    return bestScore <= 0.34 && best != query.trim() ? best : null;
  }

  Future<List<MediaItem>> search(String q, String lang) async {
    error = null;
    lastCorrectedQuery = null;
    final query = q.trim();
    if (query.isEmpty) return [];

    final r = <MediaItem>[];
    try {
      r.addAll(await tmdb.search(query, lang: lang));
      if (r.isEmpty || lang != 'en') {
        try {
          final english = await tmdb.search(query, lang: 'en');
          for (final item in english) {
            if (!r.any((x) => x.id == item.id && x.mediaType == item.mediaType)) r.add(item);
          }
        } catch (_) {}
      }
      if (r.isEmpty) {
        final corrected = _correctQuery(query);
        if (corrected != null) {
          final correctedResults = await tmdb.search(corrected, lang: lang);
          if (correctedResults.isNotEmpty) {
            lastCorrectedQuery = corrected;
            r.addAll(correctedResults);
          }
        }
      }
    } catch (e) {
      error = e.toString();
    }

    try {
      if (r.isEmpty) r.addAll(await jikan.searchAnime(query));
    } catch (_) {}

    await database.addSearch(query);
    return r;
  }

  Future<List<MediaItem>> trending(String lang) async {
    loading = true; notifyListeners();
    try { return await tmdb.getTrending(lang: lang); }
    finally { loading = false; notifyListeners(); }
  }

  Future<List<MediaItem>> topRated(String lang) async {
    try { return await tmdb.getTopRated(lang: lang); } catch (_) { return []; }
  }

  Future<List<MediaItem>> topAnime() => jikan.topAnime();

  Future<List<MediaItem>> recommendations(MediaItem item, String lang) async {
    if (item.mediaType == 'anime') return jikan.topAnime();
    try { return await tmdb.getRecommendations(item.id, item.mediaType, lang: lang); } catch (_) { return []; }
  }

  Future<MediaItem> details(MediaItem item, String lang) async {
    if (item.mediaType == 'anime') return item;
    try { return await tmdb.getDetails(item.id, item.mediaType, lang: lang); } catch (_) { return item; }
  }

  UserStats get stats {
    final watched = _library.where((x) => x.watchStatus == AppConstants.statusWatched).toList();
    final watching = _library.where((x) => x.watchStatus == AppConstants.statusWatching).length;
    final genres = <String, int>{}, actors = <String, int>{};
    double hours = 0, sum = 0;
    int rated = 0, m = 0, t = 0, a = 0;
    for (final x in watched) {
      if (x.mediaType == 'movie') m++; else if (x.mediaType == 'tv') t++; else a++;
      hours += (x.runtime ?? 0) / 60;
      for (final g in x.genres) genres[g] = (genres[g] ?? 0) + 1;
      for (final c in x.cast.take(10)) actors[c] = (actors[c] ?? 0) + 1;
      if (x.userRating != null) { sum += x.userRating!; rated++; }
    }
    Map<String, int> top(Map<String, int> v) {
      final e = v.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      return Map.fromEntries(e.take(8));
    }
    return UserStats(
      totalWatched: watched.length, totalWatching: watching,
      totalWatchlist: _library.where((x) => x.watchStatus == AppConstants.statusNotWatched).length,
      totalHours: hours, movies: m, tvShows: t, anime: a,
      averageRating: rated == 0 ? 0 : sum / rated,
      topGenres: top(genres), topActors: top(actors),
    );
  }
}
