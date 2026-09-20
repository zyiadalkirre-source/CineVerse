import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../core/constants.dart';
import '../core/state/media_state.dart';
import '../models/media_item.dart';
import '../models/user_stats.dart';
import '../services/database_service.dart';
import '../services/notification_center_service.dart';
import '../repositories/media_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MediaProvider extends ChangeNotifier {
  MediaProvider({
    MediaRepository? repository,
    DatabaseService? database,
  })  : _repository = repository ??
            MediaRepository(
              database: database ?? DatabaseService.instance,
            ),
        _ownsRepository = repository == null,
        database = database ?? DatabaseService.instance {
    _initEviction();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  final MediaRepository _repository;
  final bool _ownsRepository;
  final DatabaseService database;

  MediaRepository get repository => _repository;
  List<MediaItem> _library = [];
  bool loading = false;
  String? error;
  String? lastCorrectedQuery;

  MediaState _trendingState = const MediaState();
  MediaState _topRatedState = const MediaState();
  MediaState _animeState = const MediaState();
  MediaState _detailsState = const MediaState();
  MediaState _searchState = const MediaState();

  StreamSubscription<List<MediaItem>>? _trendingSub;
  StreamSubscription<List<MediaItem>>? _topRatedSub;
  StreamSubscription<List<MediaItem>>? _animeSub;
  StreamSubscription<MediaItem>? _detailsSub;

  MediaState get trendingState => _trendingState;
  MediaState get topRatedState => _topRatedState;
  MediaState get animeState => _animeState;
  MediaState get detailsState => _detailsState;
  MediaState get searchState => _searchState;

  void _initEviction() {
    unawaited(_repository.pruneCacheSilently());
  }

  List<MediaItem> get library => List.unmodifiable(_library);


  Future<void> _load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      _library = await database.getLibrary();
      try {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getBool('notifyNewEpisodes') == true) {
          await NotificationCenterService.checkForNewEpisodes(
            favoriteShows: _library.where((x) => x.isFavorite && x.mediaType == AppConstants.typeTv).toList(),
            repository: _repository,
            updateItem: upsert,
          );
        }
      } catch (e, st) {
        debugPrint('Media notification check failed: $e\n$st');
      }
    } catch (e, st) {
      final normalized = _normalizeMediaError(e);
      error = normalized.message;
      debugPrint('MediaProvider load failed: $e\n$st');
    } finally {
      loading = false;
      notifyListeners();
    }
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
      await database.saveMedia(item, enqueueSync: false);
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

    if (query.isEmpty) {
      _searchState = const MediaState(status: MediaStatus.success);
      notifyListeners();
      return const <MediaItem>[];
    }

    loading = true;
    _searchState = _searchState.copyWith(
      status: MediaStatus.loading,
      isBackgroundRefreshing: false,
      clearError: true,
      clearErrorCode: true,
    );
    notifyListeners();

    try {
      var results = await _repository.search(query, lang: lang);

      if (results.isEmpty) {
        final corrected = _correctQuery(query);
        if (corrected != null) {
          final correctedResults = await _repository.search(
            corrected,
            lang: lang,
            forceRefresh: true,
          );
          if (correctedResults.isNotEmpty) {
            lastCorrectedQuery = corrected;
            results = correctedResults;
          }
        }
      }

      await database.addSearch(query);
      _searchState = _searchState.copyWith(
        status: MediaStatus.success,
        items: results,
        isOffline: false,
        clearError: true,
        clearErrorCode: true,
      );
      return results;
    } catch (e, st) {
      final normalized = _normalizeMediaError(e);
      error = normalized.message;
      _searchState = _stateFromError(_searchState, normalized);
      debugPrint('MediaProvider search failed: $e\n$st');
      return const <MediaItem>[];
    } finally {
      loading = false;
      notifyListeners();
    }
  }
  Future<List<MediaItem>> trending(String lang) async {
    await fetchTrending(lang: lang);
    return _trendingState.items;
  }

  Future<void> fetchTrending({
    String lang = 'ar',
    bool forceRefresh = false,
  }) async {
    loading = true;
    _trendingState = _trendingState.copyWith(
      status: MediaStatus.loading,
      isBackgroundRefreshing: forceRefresh,
      clearError: true,
      clearErrorCode: true,
    );
    notifyListeners();

    try {
      final items = await _repository.getTrending(
        lang: lang,
        forceRefresh: forceRefresh,
      );
      _trendingState = _trendingState.copyWith(
        status: MediaStatus.success,
        items: items,
        isOffline: false,
        isBackgroundRefreshing: false,
        clearError: true,
        clearErrorCode: true,
      );
    } catch (e, st) {
      final normalized = _normalizeMediaError(e);
      final cached = await _safeTrendingCache(lang);
      if (cached.isNotEmpty) {
        _trendingState = _trendingState.copyWith(
          status: MediaStatus.refreshFailed,
          items: cached,
          errorMessage: normalized.message,
          errorCode: normalized.code,
          isOffline: normalized.isOffline,
          isBackgroundRefreshing: false,
        );
      } else {
        _trendingState = _trendingState.copyWith(
          status: MediaStatus.error,
          errorMessage: normalized.message,
          errorCode: normalized.code,
          isOffline: normalized.isOffline,
          isBackgroundRefreshing: false,
        );
      }
      error = normalized.message;
      debugPrint('MediaProvider trending failed: $e\n$st');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<List<MediaItem>> _safeTrendingCache(String lang) async {
    try {
      return await _repository.getTrending(lang: lang);
    } catch (_) {
      return const <MediaItem>[];
    }
  }

  void watchTrending({String lang = 'ar'}) {
    unawaited(_trendingSub?.cancel());
    _trendingState = _trendingState.copyWith(
      status: MediaStatus.loading,
      isBackgroundRefreshing: true,
      clearError: true,
      clearErrorCode: true,
    );
    notifyListeners();
    _trendingSub = _repository.watchTrending(lang: lang).listen(
      (items) {
        _trendingState = _trendingState.copyWith(
          status: MediaStatus.success,
          items: items,
          isOffline: false,
          isBackgroundRefreshing: false,
          clearError: true,
          clearErrorCode: true,
        );
        error = null;
        notifyListeners();
      },
      onError: (Object e, StackTrace st) {
        final normalized = _normalizeMediaError(e);
        final hasData = _trendingState.items.isNotEmpty;
        _trendingState = _trendingState.copyWith(
          status: hasData ? MediaStatus.refreshFailed : MediaStatus.error,
          errorMessage: normalized.message,
          errorCode: normalized.code,
          isOffline: normalized.isOffline,
          isBackgroundRefreshing: false,
        );
        error = normalized.message;
        debugPrint('MediaProvider trending stream failed: $e\n$st');
        notifyListeners();
      },
    );
  }

  Future<List<MediaItem>> topRated(String lang) async {
    loading = true;
    try {
      final items = await _repository.getTopRated(lang: lang);
      _topRatedState = _topRatedState.copyWith(
        status: MediaStatus.success,
        items: items,
        isOffline: false,
        clearError: true,
        clearErrorCode: true,
      );
      return items;
    } catch (e) {
      final normalized = _normalizeMediaError(e);
      error = normalized.message;
      _topRatedState = _stateFromError(_topRatedState, normalized);
      return const <MediaItem>[];
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<List<MediaItem>> topAnime() async {
    loading = true;
    try {
      final items = await _repository.getTopAnime();
      _animeState = _animeState.copyWith(
        status: MediaStatus.success,
        items: items,
        isOffline: false,
        clearError: true,
        clearErrorCode: true,
      );
      return items;
    } catch (e) {
      final normalized = _normalizeMediaError(e);
      error = normalized.message;
      _animeState = _stateFromError(_animeState, normalized);
      return const <MediaItem>[];
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<List<MediaItem>> recommendations(MediaItem item, String lang) async {
    try {
      return await _repository.getRecommendations(item, lang: lang);
    } catch (e) {
      final normalized = _normalizeMediaError(e);
      error = normalized.message;
      return const <MediaItem>[];
    }
  }

  Future<MediaItem> details(MediaItem item, String lang) async {
    _detailsState = _detailsState.copyWith(
      status: MediaStatus.loading,
      selectedItem: item,
      clearError: true,
      clearErrorCode: true,
    );
    notifyListeners();
    try {
      final result = await _repository.getDetails(item, lang: lang);
      _detailsState = _detailsState.copyWith(
        status: MediaStatus.success,
        selectedItem: result,
        isOffline: false,
        clearError: true,
        clearErrorCode: true,
      );
      return result;
    } catch (e) {
      final normalized = _normalizeMediaError(e);
      error = normalized.message;
      _detailsState = _stateFromError(_detailsState, normalized);
      return item;
    } finally {
      notifyListeners();
    }
  }

  MediaState _stateFromError(
    MediaState current,
    _NormalizedMediaError normalized,
  ) {
    return current.copyWith(
      status: current.hasData
          ? MediaStatus.refreshFailed
          : MediaStatus.error,
      errorMessage: normalized.message,
      errorCode: normalized.code,
      isOffline: normalized.isOffline,
      isBackgroundRefreshing: false,
    );
  }

  _NormalizedMediaError _normalizeMediaError(Object error) {
    if (error is TmdbException) {
      switch (error.code) {
        case 'NETWORK':
        case 'TIMEOUT':
          return const _NormalizedMediaError(
            code: 'OFFLINE',
            message: 'لا يوجد اتصال بالإنترنت حالياً، ولا توجد نسخة محفوظة لهذا المحتوى. حاول مرة أخرى.',
            isOffline: true,
          );
        case 'RATE_LIMIT':
          return const _NormalizedMediaError(
            code: 'RATE_LIMIT',
            message: 'تم تجاوز حد الطلبات مؤقتاً. حاول مرة أخرى بعد قليل.',
            isOffline: false,
          );
        case 'UNAUTHORIZED':
        case 'MISSING_API_KEY':
          return const _NormalizedMediaError(
            code: 'SERVICE_NOT_CONFIGURED',
            message: 'خدمة المحتوى غير مهيأة حالياً. جرّب مرة أخرى لاحقاً.',
            isOffline: false,
          );
        case 'NOT_FOUND':
          return const _NormalizedMediaError(
            code: 'NOT_FOUND',
            message: 'لم يتم العثور على المحتوى المطلوب.',
            isOffline: false,
          );
        case 'SERVER_ERROR':
          return const _NormalizedMediaError(
            code: 'SERVER_ERROR',
            message: 'خدمة المحتوى تواجه مشكلة مؤقتة. حاول مرة أخرى لاحقاً.',
            isOffline: false,
          );
      }
    }

    if (error is SocketException || error is TimeoutException) {
      return const _NormalizedMediaError(
        code: 'OFFLINE',
        message: 'لا يوجد اتصال بالإنترنت حالياً، ولا توجد نسخة محفوظة لهذا المحتوى. حاول مرة أخرى.',
        isOffline: true,
      );
    }

    if (error is ArgumentError) {
      return const _NormalizedMediaError(
        code: 'INVALID_MEDIA_TYPE',
        message: 'نوع المحتوى المطلوب غير مدعوم.',
        isOffline: false,
      );
    }

    return const _NormalizedMediaError(
      code: 'MEDIA_LOAD_FAILED',
      message: 'تعذر تحميل المحتوى حالياً. حاول مرة أخرى.',
      isOffline: false,
    );
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

  @override
  void dispose() {
    unawaited(_trendingSub?.cancel());
    unawaited(_topRatedSub?.cancel());
    unawaited(_animeSub?.cancel());
    unawaited(_detailsSub?.cancel());

    if (_ownsRepository) {
      unawaited(_repository.dispose());
    }

    super.dispose();
  }


class _NormalizedMediaError {
  const _NormalizedMediaError({
    required this.code,
    required this.message,
    required this.isOffline,
  });

  final String code;
  final String message;
  final bool isOffline;
}
