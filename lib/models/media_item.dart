class MediaItem {
  final int id;
  final String title;
  final String overview;
  final String? posterPath;
  final String? backdropPath;
  final double voteAverage;
  final String? releaseDate;
  final String mediaType;

  const MediaItem({
    required this.id, required this.title, required this.overview,
    this.posterPath, this.backdropPath, required this.voteAverage,
    this.releaseDate, required this.mediaType,
  });

  factory MediaItem.fromJson(Map<String, dynamic> json) => MediaItem(
    id: (json['id'] as num?)?.toInt() ?? 0,
    title: (json['title'] ?? json['name'] ?? 'بدون عنوان').toString(),
    overview: (json['overview'] ?? '').toString(),
    posterPath: json['poster_path']?.toString(),
    backdropPath: json['backdrop_path']?.toString(),
    voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0.0,
    releaseDate: (json['release_date'] ?? json['first_air_date'])?.toString(),
    mediaType: (json['media_type'] ?? 'movie').toString(),
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'overview': overview,
    'poster_path': posterPath, 'backdrop_path': backdropPath,
    'vote_average': voteAverage, 'release_date': releaseDate, 'media_type': mediaType,
  };
}
