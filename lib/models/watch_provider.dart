class WatchProvider {
  const WatchProvider({
    required this.id,
    required this.name,
    required this.type,
    this.logoPath,
  });

  final int id;
  final String name;
  final String type;
  final String? logoPath;

  String get logoUrl {
    if (logoPath == null || logoPath!.isEmpty) return '';
    return 'https://image.tmdb.org/t/p/w92$logoPath';
  }
}
