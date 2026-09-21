const _copyWithUnset = Object();

class MediaItem {
  final int id;
  final String title;
  final String? originalTitle;
  final String overview;
  final String? posterPath;
  final String? backdropPath;
  final double voteAverage;
  final int voteCount;
  final String? releaseDate;
  final String mediaType;
  final List<String> genres;
  final List<String> cast;
  final String? director;
  final int? runtime;
  final int? seasons;
  final int? episodes;
  final String? trailerKey;
  final String watchStatus;
  final double? userRating;
  final String? userTaste;
  final String notes;
  final bool isFavorite;
  final int lastWatchedSeconds;
  final int? lastWatchedSeason;
  final int? lastWatchedEpisode;
  final String? lastWatchedEpisodeName;

  const MediaItem({
    required this.id, required this.title, this.originalTitle, required this.overview,
    this.posterPath, this.backdropPath, required this.voteAverage, this.voteCount = 0,
    this.releaseDate, required this.mediaType, this.genres = const [], this.cast = const [],
    this.director, this.runtime, this.seasons, this.episodes, this.trailerKey,
    this.watchStatus = 'not_watched', this.userRating, this.userTaste, this.notes = '',
    this.isFavorite = false, this.lastWatchedSeconds = 0, this.lastWatchedSeason,
    this.lastWatchedEpisode, this.lastWatchedEpisodeName,
  });

  String get year => releaseDate != null && releaseDate!.length >= 4 ? releaseDate!.substring(0, 4) : '—';
  String? get posterUrl => posterPath == null || posterPath!.isEmpty ? null : (posterPath!.startsWith('http') ? posterPath : 'https://image.tmdb.org/t/p/w500$posterPath');
  String? get backdropUrl => backdropPath == null || backdropPath!.isEmpty ? null : (backdropPath!.startsWith('http') ? backdropPath : 'https://image.tmdb.org/t/p/original$backdropPath');

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    final genres = <String>[];
    final rawGenres = json['genres'];
    if (rawGenres is List) for (final g in rawGenres) {
      if (g is Map && g['name'] != null) genres.add(g['name'].toString());
      else if (g is String) genres.add(g);
    }
    final rawCast = json['cast'];
    final cast = rawCast is List ? rawCast.map((e) => e is Map ? (e['name'] ?? '').toString() : e.toString()).where((e) => e.isNotEmpty).toList() : <String>[];
    return MediaItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: (json['title'] ?? json['name'] ?? 'بدون عنوان').toString(),
      originalTitle: (json['original_title'] ?? json['original_name'])?.toString(),
      overview: (json['overview'] ?? '').toString(),
      posterPath: json['poster_path']?.toString(),
      backdropPath: json['backdrop_path']?.toString(),
      voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0,
      voteCount: (json['vote_count'] as num?)?.toInt() ?? 0,
      releaseDate: (json['release_date'] ?? json['first_air_date'])?.toString(),
      mediaType: (json['media_type'] ?? (json.containsKey('first_air_date') ? 'tv' : 'movie')).toString(),
      genres: genres, cast: cast, director: json['director']?.toString(),
      runtime: (json['runtime'] as num?)?.toInt(),
      seasons: (json['number_of_seasons'] as num?)?.toInt() ?? (json['seasons_count'] as num?)?.toInt(),
      episodes: (json['number_of_episodes'] as num?)?.toInt() ?? (json['episodes'] as num?)?.toInt(),
      trailerKey: json['trailer_key']?.toString(),
      watchStatus: (json['watch_status'] ?? 'not_watched').toString(),
      userRating: (json['user_rating'] as num?)?.toDouble(),
      userTaste: json['user_taste']?.toString(),
      notes: (json['notes'] ?? '').toString(),
      isFavorite: json['is_favorite'] == true,
      lastWatchedSeconds: (json['last_watched_seconds'] as num?)?.toInt() ?? 0,
      lastWatchedSeason: (json['last_watched_season'] as num?)?.toInt(),
      lastWatchedEpisode: (json['last_watched_episode'] as num?)?.toInt(),
      lastWatchedEpisodeName: json['last_watched_episode_name']?.toString(),
    );
  }

  MediaItem copyWith({
    int? id,String? title,String? originalTitle,String? overview,String? posterPath,String? backdropPath,
    double? voteAverage,int? voteCount,String? releaseDate,String? mediaType,List<String>? genres,List<String>? cast,
    String? director,int? runtime,int? seasons,int? episodes,String? trailerKey,String? watchStatus,
    Object? userRating=_copyWithUnset,Object? userTaste=_copyWithUnset,String? notes,bool? isFavorite,int? lastWatchedSeconds,
    int? lastWatchedSeason,int? lastWatchedEpisode,String? lastWatchedEpisodeName,
  }) => MediaItem(
    id:id??this.id,title:title??this.title,originalTitle:originalTitle??this.originalTitle,overview:overview??this.overview,
    posterPath:posterPath??this.posterPath,backdropPath:backdropPath??this.backdropPath,voteAverage:voteAverage??this.voteAverage,
    voteCount:voteCount??this.voteCount,releaseDate:releaseDate??this.releaseDate,mediaType:mediaType??this.mediaType,
    genres:genres??this.genres,cast:cast??this.cast,director:director??this.director,runtime:runtime??this.runtime,
    seasons:seasons??this.seasons,episodes:episodes??this.episodes,trailerKey:trailerKey??this.trailerKey,
    watchStatus:watchStatus??this.watchStatus,userRating:userRating==_copyWithUnset?this.userRating:userRating as double?,userTaste:userTaste==_copyWithUnset?this.userTaste:userTaste as String?,notes:notes??this.notes,
    isFavorite:isFavorite??this.isFavorite,lastWatchedSeconds:lastWatchedSeconds??this.lastWatchedSeconds,
    lastWatchedSeason:lastWatchedSeason??this.lastWatchedSeason,lastWatchedEpisode:lastWatchedEpisode??this.lastWatchedEpisode,
    lastWatchedEpisodeName:lastWatchedEpisodeName??this.lastWatchedEpisodeName);

  Map<String,dynamic> toJson()=>{
    'id':id,'title':title,'original_title':originalTitle,'overview':overview,'poster_path':posterPath,'backdrop_path':backdropPath,
    'vote_average':voteAverage,'vote_count':voteCount,'release_date':releaseDate,'media_type':mediaType,'genres':genres,'cast':cast,
    'director':director,'runtime':runtime,'number_of_seasons':seasons,'number_of_episodes':episodes,'trailer_key':trailerKey,
    'watch_status':watchStatus,'user_rating':userRating,'user_taste':userTaste,'notes':notes,'is_favorite':isFavorite,
    'last_watched_seconds':lastWatchedSeconds,'last_watched_season':lastWatchedSeason,'last_watched_episode':lastWatchedEpisode,
    'last_watched_episode_name':lastWatchedEpisodeName,
  };
}