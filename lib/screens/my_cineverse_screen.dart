import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../models/media_item.dart';
import '../providers/media_provider.dart';
import 'detail_screen.dart';
import 'stats_screen.dart';
import 'notifications_screen.dart';
import 'account_screen.dart';

class MyCineVerseScreen extends StatelessWidget {
  const MyCineVerseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MediaProvider>();
    final library = provider.library;

    final continueWatching = library.where((item) => item.lastWatchedSeconds > 0).toList()
      ..sort((a, b) => b.lastWatchedSeconds.compareTo(a.lastWatchedSeconds));
    final myList = library.where((item) => item.watchStatus == AppConstants.statusNotWatched).toList();
    final favorites = library.where((item) => item.isFavorite).toList();
    final liked = library.where((item) => item.userTaste == 'love' || item.userTaste == 'like').toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My CineVerse'),
          actions: [
            IconButton(
              tooltip: 'الإحصائيات',
              icon: const Icon(Icons.bar_chart_rounded),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StatsScreen()),
              ),
            ),
            IconButton(
              tooltip: 'الحساب والمزامنة',
              icon: const Icon(Icons.account_circle_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AccountScreen()),
              ),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () async => provider.fetchTrending(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _summaryCard(context, library),
              const SizedBox(height: 16),
              _quickActions(context),
              if (continueWatching.isNotEmpty) ...[
                const SizedBox(height: 22),
                _row(context, 'تابع المشاهدة', continueWatching),
              ],
              if (myList.isNotEmpty) ...[
                const SizedBox(height: 22),
                _row(context, 'قائمتي', myList),
              ],
              if (favorites.isNotEmpty) ...[
                const SizedBox(height: 22),
                _row(context, 'المفضلة', favorites),
              ],
              if (liked.isNotEmpty) ...[
                const SizedBox(height: 22),
                _row(context, 'أعمال أعجبتك', liked),
              ],
              if (library.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 70),
                  child: Column(
                    children: [
                      Icon(Icons.movie_filter_outlined, size: 64),
                      SizedBox(height: 12),
                      Text(
                        'ابدأ بإضافة أفلام ومسلسلات وأنمي إلى مكتبتك.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 18),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.tips_and_updates_outlined),
                  title: const Text('نصيحة'),
                  subtitle: const Text(
                    'استخدم الإعجاب والمفضلة والمتابعة لبناء «مختار لك» بشكل أدق.',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.notifications_none_rounded),
                  title: const Text('الإشعارات'),
                  subtitle: const Text('مواعيد الحلقات والتنبيهات محفوظة هنا.'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryCard(BuildContext context, List<MediaItem> library) {
    final watched = library.where((item) => item.watchStatus == AppConstants.statusWatched).length;
    final watching = library.where((item) => item.watchStatus == AppConstants.statusWatching).length;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.secondary,
            ],
          ),
        ),
        child: DefaultTextStyle(
          style: const TextStyle(color: Colors.white),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'مساحتك السينمائية',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                library.length.toString() +
                    ' عمل • ' +
                    watched.toString() +
                    ' تمت مشاهدته • ' +
                    watching.toString() +
                    ' قيد المشاهدة',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Theme.of(context).colorScheme.primary,
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StatsScreen()),
                ),
                icon: const Icon(Icons.insights_rounded),
                label: const Text('عرض الإحصائيات'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Card(
            margin: EdgeInsets.zero,
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 17),
                child: Column(
                  children: [
                    Icon(Icons.notifications_none_rounded),
                    SizedBox(height: 6),
                    Text('الإشعارات'),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Card(
            margin: EdgeInsets.zero,
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AccountScreen()),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 17),
                child: Column(
                  children: [
                    Icon(Icons.cloud_sync_outlined),
                    SizedBox(height: 6),
                    Text('الحساب'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, String title, List<MediaItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 245,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final item = items[i];
              return SizedBox(
                width: 135,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => DetailScreen(item: item)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: item.posterUrl == null
                              ? Container(
                                  width: double.infinity,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                  child: const Icon(Icons.movie_outlined),
                                )
                              : Image.network(
                                  item.posterUrl!,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Center(
                                    child: Icon(Icons.broken_image_outlined),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        item.year,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
