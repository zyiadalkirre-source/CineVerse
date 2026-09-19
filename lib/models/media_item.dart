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

  const MediaItem({
    required this.id,
    required this.title,
    this.originalTitle,
    required this.overview,
    this.posterPath,
    this.backdropPath,
    required this.voteAverage,
    this.voteCount = 0,
    this.releaseDate,
    required this.mediaType,
    this.genres = const [],
    this.cast = const [],
    this.director,
    this.runtime,
    this.seasons,
    this.episodes,
    this.trailerKey,
  });

  String get year =>
      releaseDate != null && releaseDate!.length >= 4
          ? releaseDate!.substring(0, 4)
          : '';

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    final genreNames = <String>[];
    final rawGenres = json['genres'];
    if (rawGenres is List) {
      for (final g in rawGenres) {
        if (g is Map && g['name'] != null) genreNames.add(g['name'].toString());
        if (g is String) genreNames.add(g);
      }
    }

    return MediaItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: (json['title'] ?? json['name'] ?? 'بدون عنوان').toString(),
      originalTitle: (json['original_title'] ?? json['original_name'])?.toString(),
      overview: (json['overview'] ?? '').toString(),
      posterPath: json['poster_path']?.toString(),
      backdropPath: json['backdrop_path']?.toString(),
      voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0.0,
      voteCount: (json['vote_count'] as num?)?.toInt() ?? 0,
      releaseDate: (json['release_date'] ?? json['first_air_date'])?.toString(),
      mediaType: (json['media_type'] ?? (json.containsKey('first_air_date') ? 'tv' : 'movie')).toString(),
      genres: genreNames,
      cast: json['cast'] is List ? List<String>.from(json['cast'].map((e) => e.toString())) : const [],
      director: json['director']?.toString(),
      runtime: (json['runtime'] as num?)?.toInt(),
      seasons: (json['number_of_seasons'] as num?)?.toInt() ?? (json['seasons_count'] as num?)?.toInt(),
      episodes: (json['number_of_episodes'] as num?)?.toInt() ?? (json['episodes'] as num?)?.toInt(),
      trailerKey: json['trailer_key']?.toString(),
    );
  }

  MediaItem copyWith({
    int? id,
    String? title,
    String? originalTitle,
    String? overview,
    String? posterPath,
    String? backdropPath,
    double? voteAverage,
    int? voteCount,
    String? releaseDate,
    String? mediaType,
    List<String>? genres,
    List<String>? cast,
    String? director,
    int? runtime,
    int? seasons,
    int? episodes,
    String? trailerKey,
  }) => MediaItem(
    id: id ?? this.id,
    title: title ?? this.title,
    originalTitle: originalTitle ?? this.originalTitle,
    overview: overview ?? this.overview,
    posterPath: posterPath ?? this.posterPath,
    backdropPath: backdropPath ?? this.backdropPath,
    voteAverage: voteAverage ?? this.voteAverage,
    voteCount: voteCount ?? this.voteCount,
    releaseDate: releaseDate ?? this.releaseDate,
    mediaType: mediaType ?? this.mediaType,
    genres: genres ?? this.genres,
    cast: cast ?? this.cast,
    director: director ?? this.director,
    runtime: runtime ?? this.runtime,
    seasons: seasons ?? this.seasons,
    episodes: episodes ?? this.episodes,
    trailerKey: trailerKey ?? this.trailerKey,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'original_title': originalTitle,
    'overview': overview,
    'poster_path': posterPath,
    'backdrop_path': backdropPath,
    'vote_average': voteAverage,
    'vote_count': voteCount,
    'release_date': releaseDate,
    'media_type': mediaType,
    'genres': genres,
    'cast': cast,
    'director': director,
    'runtime': runtime,
    'number_of_seasons': seasons,
    'number_of_episodes': episodes,
    'trailer_key': trailerKey,
  };
}
