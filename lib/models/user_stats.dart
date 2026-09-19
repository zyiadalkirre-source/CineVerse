class UserStats {
  final int totalWatched;
  final int totalWatching;
  final int totalWatchlist;
  final double totalHours;
  final int movies;
  final int tvShows;
  final int anime;
  final double averageRating;
  final Map<String, int> topGenres;
  final Map<String, int> topActors;

  const UserStats({
    this.totalWatched = 0,
    this.totalWatching = 0,
    this.totalWatchlist = 0,
    this.totalHours = 0,
    this.movies = 0,
    this.tvShows = 0,
    this.anime = 0,
    this.averageRating = 0,
    this.topGenres = const <String, int>{},
    this.topActors = const <String, int>{},
  });
}
