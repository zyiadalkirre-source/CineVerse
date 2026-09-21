import 'package:flutter/material.dart';
import '../core/constants.dart';
import 'package:provider/provider.dart';
import '../l10n/translations.dart';
import '../models/media_item.dart';
import '../providers/media_provider.dart';
import '../providers/settings_provider.dart';
import '../core/firebase_bootstrap.dart';
import 'search_screen.dart';
import 'detail_screen.dart';
import 'ai_hub_screen.dart';
import 'notes_screen.dart';
import 'stats_screen.dart';
import 'settings_screen.dart';
import 'clips_screen.dart';
import 'my_cineverse_screen.dart';
import 'drawer_section_screen.dart';
import 'notifications_screen.dart';
import 'latest_updates_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/custom_drawer.dart';

int libraryGridColumnCount(double width) {
  if (width < 520) return 2;
  if (width < 900) return 3;
  return 4;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}
class _HomeScreenState extends State<HomeScreen> {
  int index = 0;
  final pages = const [_Library(), _Discover(), AiHubScreen(), NotesScreen(), StatsScreen()];
  @override Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final user = FirebaseBootstrap.configured ? FirebaseAuth.instance.currentUser : null;
    return Scaffold(
      drawer: CustomDrawer(
        userName: user?.displayName ?? '🌝 moon 🌝',
        avatarUrl: user?.photoURL,
        selectedIndex: index,
        onNotifications: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          );
        },
        onItemSelected: (selected) {
          if (selected == 16) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
            return;
          }
          if (selected == 15) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyCineVerseScreen()),
            );
            return;
          }
          if (selected == 14) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ClipsScreen()),
            );
            return;
          }
          if (selected == 0) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const LatestUpdatesScreen(),
              ),
            );
            return;
          }
          final sections = <int, DrawerSection>{
            1: DrawerSection.anime,
            2: DrawerSection.seasons,
            3: DrawerSection.globalRating,
            4: DrawerSection.arabicRating,
            5: DrawerSection.myList,
            6: DrawerSection.customList,
            7: DrawerSection.favoriteAnime,
            8: DrawerSection.favoriteCharacters,
            9: DrawerSection.history,
            10: DrawerSection.downloads,
            11: DrawerSection.popularCharacters,
            12: DrawerSection.recommendations,
            13: DrawerSection.episodeDates,
          };
          final section = sections[selected];
          if (section != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DrawerSectionScreen(section: section),
              ),
            );
          }
        },
      ),
      appBar: AppBar(
        title: Text(t.t('app_name')),
        actions: [
          IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())), icon: const Icon(Icons.search)),
          IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())), icon: const Icon(Icons.settings)),
        ],
      ),
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index, onDestinationSelected: (v) => setState(() => index = v),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.video_library_outlined), label: t.t('library')),
          NavigationDestination(icon: const Icon(Icons.explore_outlined), label: t.t('discover')),
          NavigationDestination(icon: const Icon(Icons.auto_awesome), label: t.t('ai')),
          NavigationDestination(icon: const Icon(Icons.note_outlined), label: t.t('notes')),
          NavigationDestination(icon: const Icon(Icons.bar_chart), label: t.t('stats')),
        ],
      ),
    );
  }
}
class _Library extends StatefulWidget {
  const _Library();
  @override State<_Library> createState()=>_LibraryState();
}

class _LibraryState extends State<_Library> {
  String filter = 'all';
  bool _showWelcomeBanner = true;
  bool _loadingHome = true;
  List<MediaItem> _trending = const [];
  List<MediaItem> _topRated = const [];
  List<MediaItem> _latest = const [];
  List<MediaItem> _forYou = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadHome());
  }

  Future<void> _loadHome({bool forceRefresh = false}) async {
    final provider = context.read<MediaProvider>();
    final lang = context.read<SettingsProvider>().locale.languageCode;
    if (mounted) setState(() => _loadingHome = true);

    try {
      final results = await Future.wait<List<MediaItem>>([
        provider.trending(lang),
        provider.topRated(lang),
        provider.latestUpdates(lang: lang, forceRefresh: forceRefresh),
      ]);

      final seeds = provider.library.where((item) {
        return item.userTaste == 'love' ||
            item.userTaste == 'like' ||
            item.isFavorite ||
            item.watchStatus == AppConstants.statusWatching;
      }).take(2).toList();

      final recommendationMap = <String, MediaItem>{};
      for (final seed in seeds) {
        try {
          final recs = await provider.recommendations(seed, lang);
          for (final rec in recs) {
            final key = rec.mediaType + ':' + rec.id.toString();
            if (rec.id != seed.id || rec.mediaType != seed.mediaType) {
              recommendationMap[key] = rec;
            }
          }
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _trending = results[0];
        _topRated = results[1];
        _latest = results[2];
        _forYou = recommendationMap.values.take(20).toList();
        _loadingHome = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingHome = false);
    }
  }

  List<MediaItem> _filtered(List<MediaItem> items) {
    final r = items.where((x) {
      if (filter == 'movie') return x.mediaType == 'movie';
      if (filter == 'tv') return x.mediaType == 'tv';
      if (filter == 'favorite') return x.isFavorite;
      return true;
    }).toList();

    r.sort((a, b) {
      if (a.lastWatchedSeconds > 0 && b.lastWatchedSeconds == 0) return -1;
      if (a.lastWatchedSeconds == 0 && b.lastWatchedSeconds > 0) return 1;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return r;
  }

  Widget _chip(String label, String value) => Padding(
    padding: const EdgeInsets.only(right: 7),
    child: ChoiceChip(
      label: Text(label),
      selected: filter == value,
      onSelected: (_) => setState(() => filter = value),
    ),
  );

  List<MediaItem> _topTen() {
    final merged = <String, MediaItem>{};
    for (final item in <MediaItem>[..._trending, ..._topRated, ..._latest]) {
      merged[item.mediaType + ':' + item.id.toString()] = item;
    }
    final list = merged.values.toList()
      ..sort((a, b) {
        final aScore = a.voteAverage * 10 + a.voteCount / 1000;
        final bScore = b.voteAverage * 10 + b.voteCount / 1000;
        return bScore.compareTo(aScore);
      });
    return list.take(10).toList();
  }

  MediaItem? _heroItem() {
    final watching = context.read<MediaProvider>().library
        .where((x) => x.lastWatchedSeconds > 0 && x.backdropUrl != null)
        .toList();
    if (watching.isNotEmpty) return watching.first;

    for (final item in _trending) {
      if (item.backdropUrl != null) return item;
    }
    for (final item in _latest) {
      if (item.backdropUrl != null) return item;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MediaProvider>();
    final filteredItems = _filtered(provider.library);
    final continueWatching = provider.library
        .where((x) => x.lastWatchedSeconds > 0)
        .toList()
      ..sort((a, b) => b.lastWatchedSeconds.compareTo(a.lastWatchedSeconds));
    final myList = provider.library
        .where((x) => x.watchStatus == AppConstants.statusNotWatched)
        .toList();
    final topTen = _topTen();
    final hero = _heroItem();

    return RefreshIndicator(
      onRefresh: () => _loadHome(forceRefresh: true),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (hero != null)
            SliverToBoxAdapter(child: _HeroBanner(item: hero))
          else if (_showWelcomeBanner)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.secondary,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'عالمك السينمائي',
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'اكتشف، احفظ، وتابع كل ما تحب.',
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 14),
                          FilledButton.tonalIcon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const SearchScreen()),
                            ),
                            icon: const Icon(Icons.search),
                            label: const Text('ابدأ البحث'),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _showWelcomeBanner = false),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),

          if (_loadingHome)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: LinearProgressIndicator(),
              ),
            ),

          if (continueWatching.isNotEmpty)
            SliverToBoxAdapter(
              child: _HorizontalSection(
                title: 'تابع المشاهدة',
                icon: Icons.play_circle_fill,
                items: continueWatching.take(15).toList(),
                progressMode: true,
              ),
            ),

          if (myList.isNotEmpty)
            SliverToBoxAdapter(
              child: _HorizontalSection(
                title: 'قائمتي',
                icon: Icons.bookmark,
                items: myList.take(15).toList(),
              ),
            ),

          if (_forYou.isNotEmpty)
            SliverToBoxAdapter(
              child: _HorizontalSection(
                title: 'مختار لك',
                icon: Icons.auto_awesome,
                items: _forYou.take(15).toList(),
              ),
            ),

          if (topTen.isNotEmpty)
            SliverToBoxAdapter(
              child: _HorizontalSection(
                title: 'أفضل 10 لدينا اليوم',
                icon: Icons.emoji_events_outlined,
                items: topTen,
                ranked: true,
              ),
            ),

          if (_trending.isNotEmpty)
            SliverToBoxAdapter(
              child: _HorizontalSection(
                title: 'الأكثر رواجاً الآن',
                icon: Icons.local_fire_department_outlined,
                items: _trending.take(20).toList(),
              ),
            ),

          if (_latest.isNotEmpty)
            SliverToBoxAdapter(
              child: _HorizontalSection(
                title: 'جديد وساخن',
                icon: Icons.new_releases_outlined,
                items: _latest.take(20).toList(),
              ),
            ),

          if (provider.library.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _chip('مكتبتي', 'all'),
                      _chip('أفلام', 'movie'),
                      _chip('مسلسلات', 'tv'),
                      _chip('المفضلة', 'favorite'),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: filter == 'all' ? 'كل مكتبتك' : 'نتائج الفلترة',
                icon: Icons.video_library,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: libraryGridColumnCount(MediaQuery.sizeOf(context).width),
                  childAspectRatio: 0.66,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 14,
                ),
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _DismissibleMediaCard(item: filteredItems[i]),
                  childCount: filteredItems.length,
                ),
              ),
            ),
          ] else
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'مكتبتك فاضية حالياً\nابحث عن فيلم أو مسلسل وأضفه هون.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 17),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  final MediaItem item;
  const _HeroBanner({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 430,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (item.backdropUrl != null)
            Image.network(
              item.backdropUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: theme.colorScheme.surfaceContainerHighest,
              ),
            )
          else
            Container(color: theme.colorScheme.surfaceContainerHighest),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.10),
                  Colors.black.withValues(alpha: 0.35),
                  Colors.black.withValues(alpha: 0.95),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 22,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '⭐ ' +
                      item.voteAverage.toStringAsFixed(1) +
                      '  •  ' +
                      item.year +
                      '  •  ' +
                      (item.mediaType == 'tv'
                          ? 'مسلسل'
                          : item.mediaType == 'anime'
                              ? 'أنمي'
                              : 'فيلم'),
                  style: const TextStyle(color: Colors.white70),
                ),
                if (item.overview.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    item.overview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, height: 1.25),
                  ),
                ],
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => DetailScreen(item: item)),
                      ),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('تشغيل'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => DetailScreen(item: item)),
                      ),
                      icon: const Icon(Icons.info_outline),
                      label: const Text('المزيد'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HorizontalSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<MediaItem> items;
  final bool progressMode;
  final bool ranked;

  const _HorizontalSection({
    required this.title,
    required this.icon,
    required this.items,
    this.progressMode = false,
    this.ranked = false,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _SectionHeader(title: title, icon: icon),
      SizedBox(
        height: ranked ? 245 : 232,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, i) => SizedBox(
            width: ranked ? 145 : 130,
            child: _MediaCard(
              items[i],
              progressMode: progressMode,
              rank: ranked ? i + 1 : null,
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
    ],
  );
}
class _SectionHeader extends StatelessWidget {
  final String title; final IconData icon;
  const _SectionHeader({required this.title, required this.icon});
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(18, 4, 18, 12), child: Row(children: [Icon(icon, size: 20), const SizedBox(width: 8), Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800))]));
}
class _Discover extends StatefulWidget {
  const _Discover();
  @override State<_Discover> createState() => _DiscoverState();
}
class _DiscoverState extends State<_Discover> {
  List<MediaItem> items = []; bool loading = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final provider = context.read<MediaProvider>();
    try { items = await provider.trending(context.read<SettingsProvider>().locale.languageCode); } catch (_) { items = []; }
    if (mounted) setState(() => loading = false);
  }
  @override Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (items.isEmpty) return Center(child: ElevatedButton(onPressed: () { setState(() => loading = true); _load(); }, child: const Text('إعادة المحاولة')));
    return GridView.builder(padding: const EdgeInsets.all(12), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: .62), itemCount: items.length, itemBuilder: (_, i) => _MediaCard(items[i]));
  }
}
class _DismissibleMediaCard extends StatelessWidget {
  final MediaItem item;
  const _DismissibleMediaCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('${item.mediaType}:${item.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        final provider = context.read<MediaProvider>();
        if (provider.getById(item.id, item.mediaType) == null) return false;
        return true;
      },
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Icon(
          Icons.delete_outline_rounded,
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
      ),
      onDismissed: (_) async {
        final provider = context.read<MediaProvider>();
        await provider.remove(item);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تمت إزالة «${item.title}» من مكتبتك'),
            action: SnackBarAction(
              label: 'تراجع',
              onPressed: () => provider.upsert(item),
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      },
      child: _MediaCard(item),
    );
  }
}

class _MediaCard extends StatelessWidget {
  final MediaItem item;
  final bool progressMode;
  final int? rank;
  const _MediaCard(this.item, {this.progressMode = false, this.rank});
  @override Widget build(BuildContext context) => InkWell(
    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailScreen(item: item))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: item.posterUrl == null
                    ? Container(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.movie),
                      )
                    : Image.network(
                        item.posterUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.broken_image),
                        ),
                      ),
              ),
            ),
            if (rank != null)
              Positioned(
                left: 6,
                bottom: 8,
                child: Text(
                  rank.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    shadows: [Shadow(blurRadius: 8)],
                  ),
                ),
              ),
            if (item.isFavorite)
              const Positioned(
                top: 7,
                right: 7,
                child: CircleAvatar(
                  radius: 15,
                  backgroundColor: Colors.black54,
                  child: Icon(Icons.favorite, size: 16, color: Colors.white),
                ),
              ),
            if (progressMode && item.lastWatchedSeconds > 0)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: LinearProgressIndicator(
                  minHeight: 5,
                  value: item.runtime == null || item.runtime! <= 0
                      ? 0.1
                      : (item.lastWatchedSeconds / (item.runtime! * 60)).clamp(0.0, 1.0),
                ),
              ),
          ],
        ),
      ),

      Text(
        item.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        softWrap: true,
        textAlign: TextAlign.start,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
      ),
      Text(item.year, style: Theme.of(context).textTheme.bodySmall),
    ]),
  );
}
