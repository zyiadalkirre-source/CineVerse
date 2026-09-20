import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/watch_provider.dart';

class WatchOptionsWidget extends StatelessWidget {
  const WatchOptionsWidget({
    super.key,
    this.directUrl,
    this.trailerKey,
    this.providers = const [],
    this.onPlayDirect,
    this.onPlayTrailer,
    this.onAddToWatchlist,
    this.showWatchlistAction = true,
  });

  final String? directUrl;
  final String? trailerKey;
  final List<WatchProvider> providers;
  final VoidCallback? onPlayDirect;
  final VoidCallback? onPlayTrailer;
  final VoidCallback? onAddToWatchlist;
  final bool showWatchlistAction;

  bool get _hasDirect => directUrl != null && directUrl!.trim().isNotEmpty;
  bool get _hasTrailer => trailerKey != null && trailerKey!.trim().isNotEmpty;

  Future<void> _openProvider(BuildContext context, WatchProvider provider) async {
    final link = provider.link;
    if (link == null || link.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('رابط المزود غير متاح حالياً.')),
      );
      return;
    }
    final uri = Uri.tryParse(link);
    if (uri == null || !await canLaunchUrl(uri)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح منصة المشاهدة.')),
        );
      }
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('خيارات المشاهدة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (_hasDirect)
              FilledButton.icon(
                onPressed: onPlayDirect,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('تشغيل المصدر المباشر'),
              ),
            if (_hasTrailer)
              OutlinedButton.icon(
                onPressed: onPlayTrailer,
                icon: const Icon(Icons.movie_outlined),
                label: const Text('تشغيل الترايلر الرسمي'),
              ),
            if (providers.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('متاح رسمياً عبر'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: providers.map((provider) {
                  return InkWell(
                    onTap: () => _openProvider(context, provider),
                    borderRadius: BorderRadius.circular(12),
                    child: Tooltip(
                      message: '${provider.name} — ${provider.type}',
                      child: Container(
                        width: 74,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 42,
                              height: 42,
                              child: provider.logoUrl.isEmpty
                                  ? Icon(Icons.tv_outlined, color: theme.colorScheme.primary)
                                  : ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.network(
                                        provider.logoUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Icon(Icons.tv_outlined, color: theme.colorScheme.primary),
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 6),
                            Text(provider.name, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            if (!_hasDirect && !_hasTrailer && providers.isEmpty) ...[
              const Icon(Icons.search_off_rounded, size: 42),
              const SizedBox(height: 8),
              const Text(
                'لا يوجد مصدر مشاهدة متاح حالياً. يمكنك الاحتفاظ بالعمل في قائمتك والمحاولة لاحقاً.',
                textAlign: TextAlign.center,
              ),
              if (showWatchlistAction && onAddToWatchlist != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: onAddToWatchlist,
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: const Text('إضافة إلى القائمة'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
