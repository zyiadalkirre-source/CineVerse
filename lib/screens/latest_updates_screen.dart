import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/media_item.dart';
import '../providers/media_provider.dart';
import '../providers/settings_provider.dart';
import 'detail_screen.dart';

class LatestUpdatesScreen extends StatefulWidget {
  const LatestUpdatesScreen({super.key});
  @override State<LatestUpdatesScreen> createState() => _LatestUpdatesScreenState();
}

class _LatestUpdatesScreenState extends State<LatestUpdatesScreen> {
  List<MediaItem> items = [];
  bool loading = true;
  String? error;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final provider = context.read<MediaProvider>();
      final language = context.read<SettingsProvider>().locale.languageCode;
      final result = await provider.tmdb.getLatestUpdates(lang: language);
      if (!mounted) return;
      setState(() { items = result; loading = false; error = null; });
    } catch (e) {
      if (!mounted) return;
      setState(() { loading = false; error = e.toString(); });
    }
  }

  @override Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('اخر التحديثات')),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 52),
                          const SizedBox(height: 12),
                          Text(error!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () { setState(() { loading = true; error = null; }); _load(); },
                            child: const Text('إعادة المحاولة'),
                          ),
                        ],
                      ),
                    ),
                  )
                : items.isEmpty
                    ? const Center(child: Text('لا توجد تحديثات متاحة حالياً.'))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: GridView.builder(
                          padding: const EdgeInsets.all(14),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 190, mainAxisExtent: 290,
                            crossAxisSpacing: 12, mainAxisSpacing: 14,
                          ),
                          itemCount: items.length,
                          itemBuilder: (_, i) {
                            final item = items[i];
                            return InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailScreen(item: item))),
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
                                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                                child: const Icon(Icons.movie_outlined, size: 40),
                                              )
                                            : Image.network(item.posterUrl!, fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined))),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                                  Text(
                                    (item.mediaType == 'tv' ? 'مسلسل' : 'فيلم') + ' • ⭐ ' + item.voteAverage.toStringAsFixed(1),
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
      ),
    );
  }
}