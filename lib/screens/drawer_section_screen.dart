import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../models/media_item.dart';
import '../providers/media_provider.dart';
import '../providers/settings_provider.dart';
import 'detail_screen.dart';

enum DrawerSection {
  anime,
  seasons,
  globalRating,
  arabicRating,
  myList,
  customList,
  favoriteAnime,
  favoriteCharacters,
  history,
  downloads,
  popularCharacters,
  recommendations,
  episodeDates,
}

class DrawerSectionScreen extends StatefulWidget {
  final DrawerSection section;
  const DrawerSectionScreen({super.key, required this.section});

  @override
  State<DrawerSectionScreen> createState() => _DrawerSectionScreenState();
}

class _DrawerSectionScreenState extends State<DrawerSectionScreen> {
  List<MediaItem> items = [];
  List<Map<String, dynamic>> episodeDates = [];
  Set<String> customKeys = {};
  bool loading = true;
  String? error;

  String get title {
    switch (widget.section) {
      case DrawerSection.anime: return 'لائحة الانمي';
      case DrawerSection.seasons: return 'المواسم';
      case DrawerSection.globalRating: return 'التقييم العالمي';
      case DrawerSection.arabicRating: return 'التقييم العربي';
      case DrawerSection.myList: return 'قائمتي';
      case DrawerSection.customList: return 'القائمة المخصصة';
      case DrawerSection.favoriteAnime: return 'أنمياتي المفضلة';
      case DrawerSection.favoriteCharacters: return 'شخصياتي المفضلة';
      case DrawerSection.history: return 'اخر المشاهدات';
      case DrawerSection.downloads: return 'تحميلاتي';
      case DrawerSection.popularCharacters: return 'الشخصيات الاكثر شعبية';
      case DrawerSection.recommendations: return 'التوصيات';
      case DrawerSection.episodeDates: return 'مواعيد نزول الحلقات';
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final provider = context.read<MediaProvider>();
    try {
      switch (widget.section) {
        case DrawerSection.anime:
          items = await provider.topAnime();
        case DrawerSection.seasons:
          items = await provider.jikan.seasonalNow();
        case DrawerSection.globalRating:
          items = await provider.topRated('en');
        case DrawerSection.arabicRating:
          items = await provider.topRated('ar');
        case DrawerSection.myList:
          items = provider.library.where((x) => x.watchStatus == AppConstants.statusNotWatched).toList();
        case DrawerSection.favoriteAnime:
          items = provider.library.where((x) => x.mediaType == AppConstants.typeAnime && x.isFavorite).toList();
        case DrawerSection.history:
          items = provider.library.where((x) => x.lastWatchedSeconds > 0).toList()
            ..sort((a, b) => b.lastWatchedSeconds.compareTo(a.lastWatchedSeconds));
        case DrawerSection.recommendations:
          if (provider.library.isNotEmpty) {
            items = await provider.recommendations(provider.library.first, context.read<SettingsProvider>().locale.languageCode);
          } else {
            items = await provider.trending(context.read<SettingsProvider>().locale.languageCode);
          }
        case DrawerSection.customList:
          final prefs = await SharedPreferences.getInstance();
          customKeys = (prefs.getStringList('cineverse_custom_list') ?? []).toSet();
          items = provider.library;
        case DrawerSection.downloads:
          items = [];
        case DrawerSection.favoriteCharacters:
        case DrawerSection.popularCharacters:
          items = provider.library;
        case DrawerSection.episodeDates:
          await _loadEpisodeDates(provider);
      }
    } catch (e) {
      error = e.toString();
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _loadEpisodeDates(MediaProvider provider) async {
    final shows = provider.library
        .where((x) => x.mediaType == AppConstants.typeTv && (x.seasons ?? 0) > 0)
        .take(12);
    final now = DateTime.now();

    for (final show in shows) {
      try {
        final episodes = await provider.tmdb.getTvEpisodes(show.id, show.seasons!);
        for (final e in episodes) {
          final date = DateTime.tryParse((e['air_date'] ?? '').toString());
          if (date != null && !date.isBefore(DateTime(now.year, now.month, now.day))) {
            episodeDates.add({
              'show': show,
              'episode': e,
              'season': show.seasons,
            });
          }
        }
      } catch (_) {}
    }

    episodeDates.sort(
      (a, b) => ((a['episode']['air_date'] ?? '').toString())
          .compareTo((b['episode']['air_date'] ?? '').toString()),
    );
  }

  Future<void> _toggleCustom(MediaItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '\${item.mediaType}:\${item.id}';

    setState(() {
      if (customKeys.contains(key)) {
        customKeys.remove(key);
      } else {
        customKeys.add(key);
      }
    });

    await prefs.setStringList('cineverse_custom_list', customKeys.toList());
  }

  Map<String, int> _characters() {
    final counts = <String, int>{};

    for (final item in items) {
      for (final cast in item.cast) {
        counts[cast] = (counts[cast] ?? 0) + 1;
      }
    }

    return counts;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text(title)),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, size: 52),
                          const SizedBox(height: 12),
                          Text(error!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () {
                              setState(() {
                                loading = true;
                                error = null;
                              });
                              _load();
                            },
                            child: const Text('إعادة المحاولة'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (widget.section == DrawerSection.downloads) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Text(
            'لا توجد تنزيلات وسائط محفوظة حالياً. لن يعرض CineVerse ملفاً وهمياً؛ التنزيلات ستظهر هنا بعد توفير مصدر فيديو حقيقي وقانوني.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (widget.section == DrawerSection.favoriteCharacters ||
        widget.section == DrawerSection.popularCharacters) {
      final chars = _characters().entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return chars.isEmpty
          ? const Center(child: Text('لا توجد بيانات شخصيات كافية في مكتبتك حالياً.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: chars.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (_, i) => ListTile(
                leading: CircleAvatar(child: Text('\${i + 1}')),
                title: Text(chars[i].key),
                subtitle: Text(
                  widget.section == DrawerSection.popularCharacters
                      ? 'تكرار في مكتبتك'
                      : 'شخصية من بيانات مكتبتك',
                ),
                trailing: Text('\${chars[i].value}'),
              ),
            );
    }

    if (widget.section == DrawerSection.episodeDates) {
      return episodeDates.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Text(
                  'لا توجد مواعيد قادمة معروفة لمسلسلات مكتبتك حالياً.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: episodeDates.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final data = episodeDates[i];
                final show = data['show'] as MediaItem;
                final episode = data['episode'] as Map<String, dynamic>;

                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.event_available_rounded),
                    title: Text(show.title),
                    subtitle: Text(
                      'م\${data['season']} • ح\${episode['episode_number'] ?? '—'} • \${(episode['name'] ?? 'حلقة').toString()}',
                    ),
                    trailing: Text((episode['air_date'] ?? '—').toString()),
                  ),
                );
              },
            );
    }

    if (widget.section == DrawerSection.customList) {
      return items.isEmpty
          ? const Center(child: Text('أضف أعمالاً من مكتبتك إلى القائمة المخصصة.'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final item = items[i];
                final selected = customKeys.contains('\${item.mediaType}:\${item.id}');

                return Card(
                  child: ListTile(
                    leading: _poster(item),
                    title: Text(item.title),
                    subtitle: Text(item.year),
                    trailing: IconButton(
                      tooltip: selected ? 'إزالة' : 'إضافة',
                      onPressed: () => _toggleCustom(item),
                      icon: Icon(
                        selected
                            ? Icons.check_circle
                            : Icons.add_circle_outline,
                      ),
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DetailScreen(item: item),
                      ),
                    ),
                  ),
                );
              },
            );
    }

    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Text('لا توجد نتائج متاحة حالياً.', textAlign: TextAlign.center),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(14),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 190,
        mainAxisExtent: 290,
        crossAxisSpacing: 12,
        mainAxisSpacing: 14,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _mediaCard(context, items[i]),
    );
  }

  Widget _mediaCard(BuildContext context, MediaItem item) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DetailScreen(item: item)),
      ),
      borderRadius: BorderRadius.circular(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: double.infinity,
                child: item.posterUrl == null
                    ? Container(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        child: const Icon(Icons.movie_outlined, size: 40),
                      )
                    : Image.network(
                        item.posterUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.broken_image_outlined),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
          Text(
            '⭐ \${item.voteAverage.toStringAsFixed(1)} • \${item.year}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _poster(MediaItem item) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: item.posterUrl == null
            ? const SizedBox(
                width: 48,
                height: 64,
                child: Icon(Icons.movie),
              )
            : Image.network(
                item.posterUrl!,
                width: 48,
                height: 64,
                fit: BoxFit.cover,
              ),
      );
}
