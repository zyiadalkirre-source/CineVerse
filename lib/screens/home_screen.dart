import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/translations.dart';
import '../models/media_item.dart';
import '../providers/media_provider.dart';
import '../providers/settings_provider.dart';
import 'search_screen.dart';
import 'detail_screen.dart';
import 'ai_hub_screen.dart';
import 'notes_screen.dart';
import 'stats_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int index = 0;
  final pages = const [
    _Library(), _Discover(), AiHubScreen(), NotesScreen(), StatsScreen()
  ];

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.t('app_name')),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const SearchScreen())),
            icon: const Icon(Icons.search),
          ),
          IconButton(
            onPressed: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
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

class _Library extends StatelessWidget {
  const _Library();
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MediaProvider>();
    final theme = Theme.of(context);
    return CustomScrollView(slivers: [
      SliverAppBar(
        floating: true,
        title: const Text('CineVerse', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())), icon: const Icon(Icons.search)),
          IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())), icon: const Icon(Icons.settings_outlined)),
        ],
      ),
      SliverToBoxAdapter(child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 18),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [theme.colorScheme.primary, theme.colorScheme.secondary]),
          boxShadow: [BoxShadow(color: theme.colorScheme.primary.withOpacity(.22), blurRadius: 24, offset: const Offset(0, 10))],
        ),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('عالمك السينمائي', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: Colors.white)),
            const SizedBox(height: 8),
            Text(provider.library.isEmpty ? 'اكتشف، احفظ، وتابع كل ما تحب.' : provider.library.length.toString() + ' عمل محفوظ في مكتبتك',
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 18),
            FilledButton.tonalIcon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
              icon: const Icon(Icons.explore), label: const Text('اكتشف الآن'),
            ),
          ])),
          const SizedBox(width: 10),
          const Icon(Icons.movie_filter_rounded, size: 82, color: Colors.white24),
        ]),
      )),
      if (provider.library.isNotEmpty) ...[
        const SliverToBoxAdapter(child: _SectionHeader(title: 'مكتبتك', icon: Icons.video_library)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 170, mainAxisExtent: 265, crossAxisSpacing: 12, mainAxisSpacing: 14),
            delegate: SliverChildBuilderDelegate((_, i) => _MediaCard(provider.library[i]), childCount: provider.library.length),
          ),
        ),
      ] else
        const SliverFillRemaining(hasScrollBody: false, child: Center(
          child: Padding(padding: EdgeInsets.all(32),
            child: Text('مكتبتك فاضية حالياً\nابحث عن فيلم أو مسلسل وأضفه هون.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 17))),
        )),
    ]);
  }
}

class _SectionHeader extends StatelessWidget {
  final String title; final IconData icon;
  const _SectionHeader({required this.title, required this.icon});
  @override Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
    child: Row(children: [Icon(icon, size: 20), const SizedBox(width: 8),
      Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800))]),
  );
}

class _Discover extends StatefulWidget {
  const _Discover();
  @override
  State<_Discover> createState() => _DiscoverState();
}

class _DiscoverState extends State<_Discover> {
  List<MediaItem> items = [];
  bool loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final provider = context.read<MediaProvider>();
    try {
      items = await provider.trending(
        context.read<SettingsProvider>().locale.languageCode);
    } catch (_) {
      items = [];
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (items.isEmpty) {
      return Center(
        child: ElevatedButton(
          onPressed: () {
            setState(() => loading = true);
            _load();
          },
          child: const Text('إعادة المحاولة'),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10,
        childAspectRatio: .62),
      itemCount: items.length,
      itemBuilder: (_, index) => _MediaCard(items[index]),
    );
  }
}

class _MediaCard extends StatelessWidget {
  final MediaItem item;
  const _MediaCard(this.item);
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
        context, MaterialPageRoute(builder: (_) => DetailScreen(item: item))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: item.posterUrl == null
                  ? Container(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.movie))
                  : Image.network(
                      item.posterUrl!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Center(child: Icon(Icons.broken_image))),
            ),
          ),
          const SizedBox(height: 5),
          Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
          Text(item.year, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
