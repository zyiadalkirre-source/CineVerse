import 'dart:async';

import '../core/constants.dart';
import '../models/media_item.dart';
import '../services/database_service.dart';
import '../services/jikan_service.dart';
import '../services/tmdb_service.dart';

typedef MediaCollectionFetcher = Future<List<MediaItem>> Function();
typedef MediaDetailsFetcher = Future<MediaItem> Function();

class MediaRepository {
  MediaRepository({
    DatabaseService? database,
    TmdbService? tmdb,
    JikanService? jikan,
    Duration? collectionTtl,
    Duration? detailsTtl,
  })  : _database = database ?? DatabaseService.instance,
        _tmdb = tmdb ?? TmdbService(),
        _jikan = jikan ?? JikanService(),
        _ownsTmdb = tmdb == null,
        collectionTtl = collectionTtl ?? const Duration(hours: 6),
        detailsTtl = detailsTtl ?? const Duration(hours: 24);

  final DatabaseService _database;
  final TmdbService _tmdb;
  final JikanService _jikan;
  final bool _ownsTmdb;

  final Duration collectionTtl;
  final Duration detailsTtl;

  final Map<String, StreamController<List<MediaItem>>> _collectionControllers = {};
  final Map<String, StreamController<MediaItem>> _detailsControllers = {};
  final Map<String, Future<List<MediaItem>>> _collectionRefreshes = {};
  final Map<String, Future<MediaItem>> _detailsRefreshes = {};
  final Map<String, Future<void>> _collectionPrimers = {};
  final Map<String, Future<void>> _detailsPrimers = {};

  Future<List<MediaItem>> getTrending({
    String lang = 'ar',
    bool forceRefresh = false,
  }) {
    return getCollection(
      categoryKey: _trendingKey(lang),
      forceRefresh: forceRefresh,
      fetchRemote: () => _tmdb.getTrending(lang: lang),
    );
  }

  Stream<List<MediaItem>> watchTrending({String lang = 'ar'}) {
    return watchCollection(
      categoryKey: _trendingKey(lang),
      fetchRemote: () => _tmdb.getTrending(lang: lang),
    );
  }

  Future<List<MediaItem>> getTopRated({
    String type = AppConstants.typeMovie,
    String lang = 'ar',
    bool forceRefresh = false,
  }) {
    return getCollection(
      categoryKey: _topRatedKey(type, lang),
      forceRefresh: forceRefresh,
      fetchRemote: () => _tmdb.getTopRated(type: type, lang: lang),
    );
  }

  Stream<List<MediaItem>> watchTopRated({
    String type = AppConstants.typeMovie,
    String lang = 'ar',
  }) {
    return watchCollection(
      categoryKey: _topRatedKey(type, lang),
      fetchRemote: () => _tmdb.getTopRated(type: type, lang: lang),
    );
  }

  Future<List<MediaItem>> getTopAnime({bool forceRefresh = false}) {
    return getCollection(
      categoryKey: 'top_anime',
      forceRefresh: forceRefresh,
      fetchRemote: _jikan.topAnime,
    );
  }

  Stream<List<MediaItem>> watchTopAnime() {
    return watchCollection(
      categoryKey: 'top_anime',
      fetchRemote: _jikan.topAnime,
    );
  }

  Future<List<MediaItem>> getRecommendations(
    MediaItem item, {
    String lang = 'ar',
    bool forceRefresh = false,
  }) {
    final key = 'recommendations:' + item.mediaType + ':' + item.id.toString() + ':' + lang;
    return getCollection(
      categoryKey: key,
      forceRefresh: forceRefresh,
      fetchRemote: () {
        if (item.mediaType == AppConstants.typeAnime) {
          return _jikan.topAnime();
        }
        return _tmdb.getRecommendations(item.id, item.mediaType, lang: lang);
      },
    );
  }

  Stream<List<MediaItem>> watchRecommendations(
    MediaItem item, {
    String lang = 'ar',
  }) {
    final key = 'recommendations:' + item.mediaType + ':' + item.id.toString() + ':' + lang;
    return watchCollection(
      categoryKey: key,
      fetchRemote: () {
        if (item.mediaType == AppConstants.typeAnime) {
          return _jikan.topAnime();
        }
        return _tmdb.getRecommendations(item.id, item.mediaType, lang: lang);
      },
    );
  }

  Future<List<MediaItem>> search(
    String query, {
    String lang = 'ar',
    bool forceRefresh = false,
  }) {
    final normalized = _normalizeQuery(query);
    if (normalized.isEmpty) return Future.value(const []);

    return getCollection(
      categoryKey: 'search:' + lang + ':' + normalized,
      forceRefresh: forceRefresh,
      fetchRemote: () => _searchRemote(query, lang),
    );
  }

  Stream<List<MediaItem>> watchSearch(
    String query, {
    String lang = 'ar',
  }) {
    final normalized = _normalizeQuery(query);
    if (normalized.isEmpty) return Stream.value(const []);

    return watchCollection(
      categoryKey: 'search:' + lang + ':' + normalized,
      fetchRemote: () => _searchRemote(query, lang),
    );
  }

  Future<List<MediaItem>> _searchRemote(String query, String lang) async {
    final unique = <String, MediaItem>{};

    Future<void> addTmdb(String requestedLanguage) async {
      try {
        final items = await _tmdb.search(query, lang: requestedLanguage);
        for (final item in items) {
          unique[item.mediaType + ':' + item.id.toString()] = item;
        }
      } catch (_) {}
    }

    await addTmdb(lang);
    if (lang != 'en' || unique.isEmpty) {
      await addTmdb('en');
    }

    if (unique.isEmpty) {
      try {
        final anime = await _jikan.searchAnime(query);
        for (final item in anime) {
          unique[item.mediaType + ':' + item.id.toString()] = item;
        }
      } catch (_) {}
    }

    return unique.values.toList(growable: false);
  }

  Future<MediaItem> getDetails(
    MediaItem item, {
    String lang = 'ar',
    bool forceRefresh = false,
  }) {
    final key = _detailsKey(item);
    return _getDetails(
      key: key,
      seed: item,
      forceRefresh: forceRefresh,
      fetchRemote: () => _fetchDetails(item, lang),
    );
  }

  Stream<MediaItem> watchDetails(
    MediaItem item, {
    String lang = 'ar',
  }) {
    final key = _detailsKey(item);
    final controller = _detailsControllers.putIfAbsent(
      key,
      () => StreamController<MediaItem>.broadcast(),
    );

    _primeDetails(
      key: key,
      seed: item,
      fetchRemote: () => _fetchDetails(item, lang),
    );

    return controller.stream;
  }

  Future<List<MediaItem>> getLatestUpdates({
    String lang = 'ar',
    bool forceRefresh = false,
  }) {
    return getCollection(
      categoryKey: 'latest_updates:' + lang,
      forceRefresh: forceRefresh,
      fetchRemote: () => _tmdb.getLatestUpdates(lang: lang),
    );
  }

  Stream<List<MediaItem>> watchLatestUpdates({String lang = 'ar'}) {
    return watchCollection(
      categoryKey: 'latest_updates:' + lang,
      fetchRemote: () => _tmdb.getLatestUpdates(lang: lang),
    );
  }

  Future<List<MediaItem>> getCollection({
    required String categoryKey,
    required MediaCollectionFetcher fetchRemote,
    bool forceRefresh = false,
  }) async {
    final cache = await _database.getCachedCollection(categoryKey);
    final cachedItems = cache == null
        ? <MediaItem>[]
        : await _database.getCachedCollectionItems(categoryKey);
    final cachedAt = _cachedAt(cache);
    final fresh = cachedAt != null && !_isExpired(cachedAt, collectionTtl);

    if (cachedItems.isNotEmpty || cache != null) {
      _emitCollection(categoryKey, cachedItems);
    }

    if (!forceRefresh && fresh) {
      return List.unmodifiable(cachedItems);
    }

    if (!forceRefresh && (cachedItems.isNotEmpty || cache != null)) {
      _refreshCollectionInBackground(categoryKey, fetchRemote);
      return List.unmodifiable(cachedItems);
    }

    return _refreshCollection(categoryKey, fetchRemote);
  }

  Stream<List<MediaItem>> watchCollection({
    required String categoryKey,
    required MediaCollectionFetcher fetchRemote,
  }) {
    final controller = _collectionControllers.putIfAbsent(
      categoryKey,
      () => StreamController<List<MediaItem>>.broadcast(),
    );

    _primeCollection(
      categoryKey: categoryKey,
      fetchRemote: fetchRemote,
    );

    return controller.stream;
  }

  Future<MediaItem> _getDetails({
    required String key,
    required MediaItem seed,
    required MediaDetailsFetcher fetchRemote,
    bool forceRefresh = false,
  }) async {
    final cache = await _database.getCachedMediaRecord(seed.id, seed.mediaType);
    final cachedItem = cache == null
        ? null
        : await _database.getCachedMedia(seed.id, seed.mediaType);
    final cachedAt = _cachedAt(cache);
    final fresh = cachedItem != null &&
        cachedAt != null &&
        !_isExpired(cachedAt, detailsTtl);

    if (cachedItem != null) {
      _emitDetails(key, cachedItem);
    }

    if (!forceRefresh && fresh) {
      return cachedItem!;
    }

    if (!forceRefresh && cachedItem != null) {
      _refreshDetailsInBackground(key, seed, fetchRemote);
      return cachedItem;
    }

    if (cachedItem == null && seed.id > 0) {
      _emitDetails(key, seed);
    }

    return _refreshDetails(key, fetchRemote);
  }

  Future<void> _primeCollection({
    required String categoryKey,
    required MediaCollectionFetcher fetchRemote,
  }) {
    final existing = _collectionPrimers[categoryKey];
    if (existing != null) return existing;

    final future = getCollection(
      categoryKey: categoryKey,
      fetchRemote: fetchRemote,
    ).then<void>((_) {}, onError: (Object error, StackTrace stackTrace) {
      _emitCollectionError(categoryKey, error, stackTrace);
    });

    _collectionPrimers[categoryKey] = future;
    future.whenComplete(() {
      if (identical(_collectionPrimers[categoryKey], future)) {
        _collectionPrimers.remove(categoryKey);
      }
    });
    return future;
  }

  Future<void> _primeDetails({
    required String key,
    required MediaItem seed,
    required MediaDetailsFetcher fetchRemote,
  }) {
    final existing = _detailsPrimers[key];
    if (existing != null) return existing;

    final future = _getDetails(
      key: key,
      seed: seed,
      fetchRemote: fetchRemote,
    ).then<void>((_) {}, onError: (Object error, StackTrace stackTrace) {
      _emitDetailsError(key, error, stackTrace);
    });

    _detailsPrimers[key] = future;
    future.whenComplete(() {
      if (identical(_detailsPrimers[key], future)) {
        _detailsPrimers.remove(key);
      }
    });
    return future;
  }

  Future<List<MediaItem>> _refreshCollection(
    String categoryKey,
    MediaCollectionFetcher fetchRemote,
  ) async {
    final active = _collectionRefreshes[categoryKey];
    if (active != null) return active;

    final future = _performCollectionRefresh(categoryKey, fetchRemote);
    _collectionRefreshes[categoryKey] = future;

    try {
      return await future;
    } finally {
      if (identical(_collectionRefreshes[categoryKey], future)) {
        _collectionRefreshes.remove(categoryKey);
      }
    }
  }

  Future<List<MediaItem>> _performCollectionRefresh(
    String categoryKey,
    MediaCollectionFetcher fetchRemote,
  ) async {
    final remoteItems = await fetchRemote();
    final cleaned = _deduplicate(remoteItems);
    await _database.cacheCollection(categoryKey, cleaned);
    _emitCollection(categoryKey, cleaned);
    return List.unmodifiable(cleaned);
  }

  Future<MediaItem> _refreshDetails(
    String key,
    MediaDetailsFetcher fetchRemote,
  ) async {
    final active = _detailsRefreshes[key];
    if (active != null) return active;

    final future = _performDetailsRefresh(key, fetchRemote);
    _detailsRefreshes[key] = future;

    try {
      return await future;
    } finally {
      if (identical(_detailsRefreshes[key], future)) {
        _detailsRefreshes.remove(key);
      }
    }
  }

  Future<MediaItem> _performDetailsRefresh(
    String key,
    MediaDetailsFetcher fetchRemote,
  ) async {
    final remoteItem = await fetchRemote();
    await _database.cacheDetails(remoteItem);
    _emitDetails(key, remoteItem);
    return remoteItem;
  }

  void _refreshCollectionInBackground(
    String categoryKey,
    MediaCollectionFetcher fetchRemote,
  ) {
    unawaited(_refreshCollectionSilently(categoryKey, fetchRemote));
  }

  Future<void> _refreshCollectionSilently(
    String categoryKey,
    MediaCollectionFetcher fetchRemote,
  ) async {
    try {
      await _refreshCollection(categoryKey, fetchRemote);
    } catch (_) {}
  }

  void _refreshDetailsInBackground(
    String key,
    MediaItem seed,
    MediaDetailsFetcher fetchRemote,
  ) {
    unawaited(_refreshDetailsSilently(key, seed, fetchRemote));
  }

  Future<void> _refreshDetailsSilently(
    String key,
    MediaItem seed,
    MediaDetailsFetcher fetchRemote,
  ) async {
    try {
      await _refreshDetails(key, fetchRemote);
    } catch (_) {}
  }

  Future<MediaItem> _fetchDetails(MediaItem item, String lang) async {
    if (item.mediaType == AppConstants.typeAnime) {
      final details = await _jikan.getDetails(item.id);
      return details ?? item;
    }

    if (item.mediaType != AppConstants.typeMovie &&
        item.mediaType != AppConstants.typeTv) {
      throw ArgumentError.value(
        item.mediaType,
        'mediaType',
        'Unsupported media type',
      );
    }

    return _tmdb.getDetails(item.id, item.mediaType, lang: lang);
  }

  void _emitCollection(String categoryKey, List<MediaItem> items) {
    final controller = _collectionControllers[categoryKey];
    if (controller == null || controller.isClosed) return;
    controller.add(List.unmodifiable(items));
  }

  void _emitDetails(String key, MediaItem item) {
    final controller = _detailsControllers[key];
    if (controller == null || controller.isClosed) return;
    controller.add(item);
  }

  void _emitCollectionError(
    String categoryKey,
    Object error,
    StackTrace stackTrace,
  ) {
    final controller = _collectionControllers[categoryKey];
    if (controller == null || controller.isClosed) return;
    controller.addError(error, stackTrace);
  }

  void _emitDetailsError(
    String key,
    Object error,
    StackTrace stackTrace,
  ) {
    final controller = _detailsControllers[key];
    if (controller == null || controller.isClosed) return;
    controller.addError(error, stackTrace);
  }

  int? _cachedAt(Map<String, dynamic>? row) {
    if (row == null) return null;
    final value = row['cached_at'];
    return value is int ? value : int.tryParse(value?.toString() ?? '');
  }

  bool _isExpired(int cachedAt, Duration ttl) {
    return DateTime.now().millisecondsSinceEpoch - cachedAt >= ttl.inMilliseconds;
  }

  String _trendingKey(String lang) => 'trending:' + lang;

  String _topRatedKey(String type, String lang) => 'top_rated:' + type + ':' + lang;

  String _detailsKey(MediaItem item) => 'details:' + item.mediaType + ':' + item.id.toString();

  String _normalizeQuery(String query) =>
      query.trim().replaceAll(RegExp(r'\\s+'), ' ').toLowerCase();

  List<MediaItem> _deduplicate(List<MediaItem> items) {
    final unique = <String, MediaItem>{};
    for (final item in items) {
      if (item.id <= 0) continue;
      if (item.mediaType != AppConstants.typeMovie &&
          item.mediaType != AppConstants.typeTv &&
          item.mediaType != AppConstants.typeAnime) {
        continue;
      }
      unique[item.mediaType + ':' + item.id.toString()] = item;
    }
    return unique.values.toList(growable: false);
  }

  Future<int> pruneExpiredCache({
    Duration maxAge = const Duration(days: 7),
  }) {
    return _database.pruneExpiredCache(maxAge: maxAge);
  }

  Future<void> pruneCacheSilently({
    Duration maxAge = const Duration(days: 7),
  }) async {
    try {
      await pruneExpiredCache(maxAge: maxAge);
    } catch (_) {}
  }

  Future<void> dispose() async {
    final controllers = <StreamController<dynamic>>[
      ..._collectionControllers.values,
      ..._detailsControllers.values,
    ];

    _collectionControllers.clear();
    _detailsControllers.clear();
    _collectionRefreshes.clear();
    _detailsRefreshes.clear();
    _collectionPrimers.clear();
    _detailsPrimers.clear();

    for (final controller in controllers) {
      if (!controller.isClosed) {
        await controller.close();
      }
    }

    if (_ownsTmdb) _tmdb.dispose();
  }
}
