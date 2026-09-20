class WatchProvider {
  const WatchProvider({
    required this.id,
    required this.name,
    required this.type,
    this.logoPath,
    this.link,
  });

  final int id;
  final String name;
  final String type;
  final String? logoPath;
  final String? link;

  String get logoUrl {
    if (logoPath == null || logoPath!.isEmpty) return '';
    return 'https://image.tmdb.org/t/p/w92$logoPath';
  }
}
