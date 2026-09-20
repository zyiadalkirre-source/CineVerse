import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../models/media_item.dart';
import '../providers/media_provider.dart';
import '../services/video_source_service.dart';

class WatchScreen extends StatefulWidget {
  const WatchScreen({
    super.key,
    required this.item,
    required this.title,
    required this.episodeName,
    required this.season,
    required this.episode,
    this.videoUrl,
    this.trailerKey,
  });

  final MediaItem item;
  final String title;
  final String episodeName;
  final int season;
  final int episode;
  final String? videoUrl;
  final String? trailerKey;

  @override
  State<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends State<WatchScreen> {
  VideoPlayerController? _controller;
  YoutubePlayerController? _youtubeController;
  SharedPreferences? _prefs;
  late final MediaProvider _mediaProvider;

  bool _initializing = false;
  bool _fullscreen = false;
  String? _error;
  int _lastSyncedSecond = -1;
  DateTime _lastLocalSave = DateTime.fromMillisecondsSinceEpoch(0);
  bool _savingPosition = false;

  bool get _isTrailer =>
      (widget.videoUrl == null || widget.videoUrl!.trim().isEmpty) &&
      widget.trailerKey != null &&
      widget.trailerKey!.trim().isNotEmpty;

  String get _progressKey =>
      'watch_progress_${widget.title}_${widget.season}_${widget.episode}';

  @override
  void initState() {
    super.initState();
    _mediaProvider = context.read<MediaProvider>();
    _prepare();
  }

  Future<void> _prepare() async {
    if (_isTrailer) {
      final key = widget.trailerKey!.trim();
      _youtubeController = YoutubePlayerController(
        initialVideoId: key,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
          enableCaption: true,
        ),
      );
      if (mounted) setState(() {});
      return;
    }

    _prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final episodeSaved = await _mediaProvider.getEpisodeProgress(
      item: widget.item,
      season: widget.season,
      episode: widget.episode,
    );

    final saved = episodeSaved?['position_seconds'] is int
        ? episodeSaved!['position_seconds'] as int
        : (_prefs?.getInt(_progressKey) ??
            (widget.item.lastWatchedSeason == widget.season &&
                    widget.item.lastWatchedEpisode == widget.episode
                ? widget.item.lastWatchedSeconds
                : 0));

    String? resolvedUrl = widget.videoUrl?.trim();
    if (resolvedUrl == null || resolvedUrl.isEmpty) {
      resolvedUrl = await VideoSourceService.instance.resolve(
        item: widget.item,
        season: widget.season,
        episode: widget.episode,
      );
    }

    if (resolvedUrl == null || resolvedUrl.isEmpty) {
      if (mounted) {
        setState(() {
          _error = 'لا يوجد مصدر فيديو مباشر لهذه الحلقة حالياً.';
        });
      }
      return;
    }

    final uri = Uri.tryParse(resolvedUrl);
    if (uri == null || !uri.hasScheme) {
      if (mounted) setState(() => _error = 'رابط المشاهدة غير صالح.');
      return;
    }

    setState(() => _initializing = true);

    try {
      final controller = VideoPlayerController.networkUrl(uri);
      _controller = controller;
      await controller.initialize();

      final position = Duration(seconds: saved);
      if (position > Duration.zero && position < controller.value.duration) {
        await controller.seekTo(position);
      }

      controller.addListener(_savePosition);

      if (mounted) setState(() => _initializing = false);
    } catch (_) {
      _controller?.dispose();
      _controller = null;
      if (mounted) {
        setState(() {
          _initializing = false;
          _error = 'تعذر تشغيل مصدر الفيديو. تأكد أن الرابط يعمل ويدعم الفيديو.';
        });
      }
    }
  }

  Future<void> _savePosition() async {
    final controller = _controller;
    final prefs = _prefs;

    if (controller == null ||
        prefs == null ||
        !controller.value.isInitialized) {
      return;
    }

    final seconds = controller.value.position.inSeconds;
    if (seconds <= 0 || _savingPosition) return;

    final now = DateTime.now();
    final shouldSync = (seconds - _lastSyncedSecond).abs() >= 5;
    final shouldSaveLocal =
        now.difference(_lastLocalSave) >= const Duration(seconds: 2);

    if (!shouldSync && !shouldSaveLocal) return;

    _savingPosition = true;
    try {
      if (shouldSaveLocal) {
        await prefs.setInt(_progressKey, seconds);
        _lastLocalSave = now;
      }

      if (mounted && shouldSync) {
        _lastSyncedSecond = seconds;
        await _mediaProvider.saveWatchProgress(
          widget.item,
          seconds: seconds,
          season: widget.season,
          episode: widget.episode,
          episodeName: widget.episodeName,
          durationSeconds: controller.value.duration.inSeconds,
        );
      }
    } finally {
      _savingPosition = false;
    }
  }

  Future<void> _seek(int seconds) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    var target = controller.value.position + Duration(seconds: seconds);
    if (target < Duration.zero) target = Duration.zero;
    if (target > controller.value.duration) {
      target = controller.value.duration;
    }

    await controller.seekTo(target);
  }

  Future<void> _fullscreenToggle() async {
    _fullscreen = !_fullscreen;

    if (_fullscreen) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.immersiveSticky,
      );
    } else {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }

    if (mounted) setState(() {});
  }

  @override
  void deactivate() {
    _youtubeController?.pause();
    _controller?.pause();
    super.deactivate();
  }

  @override
  void dispose() {
    _savePosition();
    _controller?.removeListener(_savePosition);
    _controller?.dispose();
    _youtubeController?.dispose();

    SystemChrome.setPreferredOrientations([]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    super.dispose();
  }

  String _time(Duration duration) {
    final hours = duration.inHours;
    final minutes =
        duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds =
        duration.inSeconds.remainder(60).toString().padLeft(2, '0');

    return hours > 0
        ? '$hours:$minutes:$seconds'
        : '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final youtube = _youtubeController;

    if (_isTrailer && youtube != null) {
      return YoutubePlayerBuilder(
        player: YoutubePlayer(
          controller: youtube,
          showVideoProgressIndicator: true,
          progressIndicatorColor: Theme.of(context).colorScheme.primary,
          progressColors: ProgressBarColors(
            playedColor: Theme.of(context).colorScheme.primary,
            handleColor: Theme.of(context).colorScheme.primary,
          ),
        ),
        builder: (context, player) => Scaffold(
          backgroundColor: Colors.black,
          appBar: _fullscreen
              ? null
              : AppBar(
                  title: Text(
                    '${widget.title} — التريلر الرسمي',
                  ),
                ),
          body: SafeArea(
            top: !_fullscreen,
            bottom: !_fullscreen,
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: player,
                    ),
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'هذا تريلر رسمي من YouTube عبر بيانات TMDB، وليس مصدراً للحلقة الكاملة.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _fullscreen
          ? null
          : AppBar(
              title: Text(
                widget.season > 0
                    ? '${widget.title} — م${widget.season} ح${widget.episode}'
                    : widget.title,
              ),
            ),
      body: SafeArea(
        top: !_fullscreen,
        bottom: !_fullscreen,
        child: Center(
          child: ready
              ? AspectRatio(
                  aspectRatio: controller.value.aspectRatio == 0
                      ? 16 / 9
                      : controller.value.aspectRatio,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      VideoPlayer(controller),
                      _Controls(
                        controller: controller,
                        format: _time,
                        onSeek: _seek,
                        onFullscreen: _fullscreenToggle,
                        fullscreen: _fullscreen,
                      ),
                    ],
                  ),
                )
              : _Status(
                  loading: _initializing,
                  error: _error,
                  episodeName: widget.episodeName,
                  trailerAvailable: widget.trailerKey != null,
                ),
        ),
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({
    required this.loading,
    required this.error,
    required this.episodeName,
    required this.trailerAvailable,
  });

  final bool loading;
  final String? error;
  final String episodeName;
  final bool trailerAvailable;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 12),
          Text(
            'جاري تجهيز المشغل...',
            style: TextStyle(color: Colors.white),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.video_library_outlined,
            color: Colors.white70,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            error ?? 'لا يوجد مصدر فيديو مباشر',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 10),
          Text(
            episodeName,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white60),
          ),
          if (trailerAvailable) ...[
            const SizedBox(height: 12),
            const Text(
              'يوجد تريلر رسمي متاح من صفحة العمل.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            'CineVerse لا ينشئ روابط مشاهدة وهمية. تشغيل الحلقة الكاملة يحتاج مصدراً قانونياً وموثوقاً من مزود المحتوى أو خدمة الباك-إند.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.controller,
    required this.format,
    required this.onSeek,
    required this.onFullscreen,
    required this.fullscreen,
  });

  final VideoPlayerController controller;
  final String Function(Duration) format;
  final Future<void> Function(int) onSeek;
  final Future<void> Function() onFullscreen;
  final bool fullscreen;

  @override
  Widget build(BuildContext context) {
    final value = controller.value;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 40, 8, 6),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black87],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          VideoProgressIndicator(
            controller,
            allowScrubbing: true,
            padding: const EdgeInsets.symmetric(vertical: 6),
            colors: const VideoProgressColors(
              playedColor: Colors.red,
              bufferedColor: Colors.white38,
              backgroundColor: Colors.white24,
            ),
          ),
          Row(
            children: [
              IconButton(
                color: Colors.white,
                icon: Icon(
                  value.isPlaying ? Icons.pause : Icons.play_arrow,
                ),
                onPressed: () =>
                    value.isPlaying ? controller.pause() : controller.play(),
              ),
              IconButton(
                color: Colors.white,
                icon: const Icon(Icons.replay_10),
                onPressed: () => onSeek(-10),
              ),
              IconButton(
                color: Colors.white,
                icon: const Icon(Icons.forward_10),
                onPressed: () => onSeek(10),
              ),
              Expanded(
                child: Text(
                  '${format(value.position)} / ${format(value.duration)}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                color: Colors.white,
                icon: Icon(
                  fullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                ),
                onPressed: onFullscreen,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
