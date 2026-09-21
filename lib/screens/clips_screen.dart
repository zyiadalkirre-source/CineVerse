import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../models/media_item.dart';
import '../providers/media_provider.dart';
import '../providers/settings_provider.dart';
import 'detail_screen.dart';

class ClipsScreen extends StatefulWidget {
  const ClipsScreen({super.key});

  @override
  State<ClipsScreen> createState() => _ClipsScreenState();
}

class _ClipEntry {
  const _ClipEntry({required this.item, required this.key});
  final MediaItem item;
  final String key;
}

class _ClipsScreenState extends State<ClipsScreen> {
  final PageController _pageController = PageController();
  final List<_ClipEntry> _clips = [];
  final Map<int, YoutubePlayerController> _controllers = {};
  bool _loading = true;
  int _activePage = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final provider = context.read<MediaProvider>();
    final lang = context.read<SettingsProvider>().locale.languageCode;

    try {
      final trending = await provider.trending(lang);
      for (final item in trending.take(12)) {
        try {
          final details = await provider.details(item, lang);
          final key = details.trailerKey?.trim();
          if (key != null && key.isNotEmpty) {
            _clips.add(_ClipEntry(item: details, key: key));
          }
        } catch (_) {}
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() => _loading = false);
    _syncController(0);
  }

  void _syncController(int index) {
    if (index < 0 || index >= _clips.length) return;

    final previous = _activePage;
    _activePage = index;

    final oldController = _controllers[previous];
    if (oldController != null && previous != index) {
      oldController.pause();
    }

    final controller = _controllers.putIfAbsent(
      index,
      () => YoutubePlayerController(
        initialVideoId: _clips[index].key,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
          enableCaption: true,
        ),
      ),
    );
    controller.play();

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_clips.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Clips')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(28),
            child: Text(
              'لا توجد مقاطع مرتبطة بالأعمال المتاحة حالياً.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Clips'),
      ),
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: _clips.length,
        onPageChanged: _syncController,
        itemBuilder: (_, index) {
          final entry = _clips[index];
          final controller = _controllers[index] ??
              YoutubePlayerController(
                initialVideoId: entry.key,
                flags: const YoutubePlayerFlags(
                  autoPlay: false,
                  mute: false,
                  enableCaption: true,
                ),
              );

          _controllers[index] = controller;

          return Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: YoutubePlayer(
                  controller: controller,
                  showVideoProgressIndicator: true,
                  progressIndicatorColor:
                      Theme.of(context).colorScheme.primary,
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 24,
                child: SafeArea(
                  top: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          shadows: [Shadow(blurRadius: 10)],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '⭐ \${entry.item.voteAverage.toStringAsFixed(1)}  •  \${entry.item.year}',
                        style: const TextStyle(
                          color: Colors.white70,
                          shadows: [Shadow(blurRadius: 8)],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DetailScreen(item: entry.item),
                              ),
                            ),
                            icon: const Icon(Icons.info_outline),
                            label: const Text('التفاصيل'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () async {
                              await context
                                  .read<MediaProvider>()
                                  .setStatus(
                                    entry.item,
                                    'not_watched',
                                  );
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('تمت الإضافة إلى قائمتي.'),
                                ),
                              );
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('قائمتي'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
