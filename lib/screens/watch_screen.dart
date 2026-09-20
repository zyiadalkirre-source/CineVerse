import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../models/media_item.dart';
import '../models/watch_provider.dart';
import '../providers/media_provider.dart';
import '../services/tmdb_service.dart';
import '../services/video_source_service.dart';
import '../widgets/watch_options_widget.dart';

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

  bool _loading = true;
  bool _fullscreen = false;
  bool _showTrailer = false;
  String? _error;
  String? _resolvedUrl;
  String? _resolvedTrailerKey;
  List<WatchProvider> _providers = const [];
  int _lastSyncedSecond = -1;
  DateTime _lastLocalSave = DateTime.fromMillisecondsSinceEpoch(0);
  bool _savingPosition = false;

  bool get _isEpisode => widget.season > 0 && widget.episode > 0;

  @override
  void initState() {
    super.initState();
    _mediaProvider = context.read<MediaProvider>();
    _prepare();
  }

  Future<void> _prepare() async {
    String? direct = widget.videoUrl?.trim();
    String? trailer = widget.trailerKey?.trim();

    try {
      if (direct == null || direct.isEmpty) {
        direct = await VideoSourceService.instance.resolve(
          item: widget.item,
          season: widget.season,
          episode: widget.episode,
        );
      }

      final tmdb = TmdbService();
      final type = widget.item.mediaType;
      if ((trailer == null || trailer.isEmpty) && type != 'anime') {
        final videos = _isEpisode
            ? await tmdb.getEpisodeVideos(widget.item.id, widget.season, widget.episode, lang: 'ar')
            : await tmdb.getVideos(widget.item.id, type, lang: 'ar');
        trailer = tmdb.findYoutubeTrailerKey(videos);
      }

      if (type != 'anime') {
        _providers = await tmdb.getWatchProviders(widget.item.id, type, region: 'SY');
      }
      tmdb.dispose();
    } catch (error) {
      _error = 'تعذر تحميل خيارات المشاهدة حالياً.';
    }

    if (!mounted) return;
    setState(() {
      _resolvedUrl = direct;
      _resolvedTrailerKey = trailer;
      _loading = false;
      _error = null;
    });

    if (_resolvedUrl != null && _resolvedUrl!.isNotEmpty) {
      await _initializeDirect();
    } else if ((_resolvedTrailerKey ?? '').isNotEmpty) {
      _showTrailer = true;
      _createYoutubeController();
    }
  }

  Future<void> _initializeDirect() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;

    final episodeSaved = await _mediaProvider.getEpisodeProgress(
      item: widget.item,
      season: widget.season,
      episode: widget.episode,
    );
    final saved = episodeSaved?['position_seconds'] is int
        ? episodeSaved!['position_seconds'] as int
        : prefs.getInt(_progressKey) ?? 0;

    final uri = Uri.tryParse(_resolvedUrl!);
    if (uri == null || !uri.hasScheme) {
      if (mounted) setState(() => _error = 'رابط المشاهدة غير صالح.');
      return;
    }

    try {
      final controller = VideoPlayerController.networkUrl(uri);
      _controller = controller;
      await controller.initialize();
      final position = Duration(seconds: saved);
      if (position > Duration.zero && position < controller.value.duration) {
        await controller.seekTo(position);
      }
      controller.addListener(_savePosition);
      if (mounted) setState(() {});
    } catch (_) {
      _controller?.dispose();
      _controller = null;
      if (mounted) setState(() => _error = 'تعذر تشغيل المصدر المباشر حالياً.');
    }
  }

  void _createYoutubeController() {
    final key = _resolvedTrailerKey?.trim();
    if (key == null || key.isEmpty) return;
    _youtubeController?.dispose();
    _youtubeController = YoutubePlayerController(
      initialVideoId: key,
      flags: const YoutubePlayerFlags(autoPlay: true, mute: false, enableCaption: true),
    );
    if (mounted) setState(() {});
  }

  void _playTrailer() {
    if ((_resolvedTrailerKey ?? '').isEmpty) return;
    setState(() => _showTrailer = true);
    _createYoutubeController();
  }

  void _playDirect() {
    setState(() => _showTrailer = false);
    if (_controller == null) _initializeDirect();
  }

  String get _progressKey => 'watch_progress_${widget.item.mediaType}_${widget.item.id}_${widget.season}_${widget.episode}';

  Future<void> _savePosition() async {
    final controller = _controller;
    final prefs = _prefs;
    if (controller == null || prefs == null || !controller.value.isInitialized || !_isEpisode) return;

    final seconds = controller.value.position.inSeconds;
    if (seconds <= 0 || _savingPosition) return;
    final now = DateTime.now();
    final shouldSync = (seconds - _lastSyncedSecond).abs() >= 5;
    final shouldSave = now.difference(_lastLocalSave) >= const Duration(seconds: 2);
    if (!shouldSync && !shouldSave) return;

    _savingPosition = true;
    try {
      if (shouldSave) {
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
    if (target > controller.value.duration) target = controller.value.duration;
    await controller.seekTo(target);
  }

  Future<void> _fullscreenToggle() async {
    _fullscreen = !_fullscreen;
    await SystemChrome.setPreferredOrientations(
      _fullscreen ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight] : [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown],
    );
    await SystemChrome.setEnabledSystemUIMode(_fullscreen ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
    if (mounted) setState(() {});
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

  @override
  Widget build(BuildContext context) {
    final directReady = _controller?.value.isInitialized == true;
    final trailer = _youtubeController;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _fullscreen
          ? null
          : AppBar(
              title: Text(_isEpisode ? '${widget.title} — م${widget.season} ح${widget.episode}' : widget.title),
            ),
      body: SafeArea(
        top: !_fullscreen,
        bottom: !_fullscreen,
        child: SingleChildScrollView(
          child: Column(
            children: [
              if (_showTrailer && trailer != null)
                YoutubePlayerBuilder(
                  player: YoutubePlayer(
                    controller: trailer,
                    showVideoProgressIndicator: true,
                    progressIndicatorColor: Theme.of(context).colorScheme.primary,
                  ),
                  builder: (context, player) => AspectRatio(aspectRatio: 16 / 9, child: player),
                )
              else if (directReady)
                AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio == 0 ? 16 / 9 : _controller!.value.aspectRatio,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      VideoPlayer(_controller!),
                      _Controls(controller: _controller!, onSeek: _seek, onFullscreen: _fullscreenToggle, fullscreen: _fullscreen),
                    ],
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(Icons.video_library_outlined, color: Colors.white70, size: 64),
                      SizedBox(height: 12),
                      Text('لا يوجد مصدر مباشر متاح حالياً.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                child: WatchOptionsWidget(
                  directUrl: _resolvedUrl,
                  trailerKey: _resolvedTrailerKey,
                  providers: _providers,
                  onPlayDirect: _resolvedUrl == null ? null : _playDirect,
                  onPlayTrailer: _resolvedTrailerKey == null ? null : _playTrailer,
                  onAddToWatchlist: () async {
                    await _mediaProvider.setStatus(widget.item, 'not_watched');
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إضافة العمل إلى القائمة.')));
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.controller, required this.onSeek, required this.onFullscreen, required this.fullscreen});

  final VideoPlayerController controller;
  final Future<void> Function(int) onSeek;
  final Future<void> Function() onFullscreen;
  final bool fullscreen;

  String _time(Duration value) {
    final h = value.inHours;
    final m = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final value = controller.value;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 40, 8, 6),
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black87]),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          VideoProgressIndicator(controller, allowScrubbing: true, padding: const EdgeInsets.symmetric(vertical: 6), colors: const VideoProgressColors(playedColor: Colors.red, bufferedColor: Colors.white38, backgroundColor: Colors.white24)),
          Row(
            children: [
              IconButton(color: Colors.white, icon: Icon(value.isPlaying ? Icons.pause : Icons.play_arrow), onPressed: () => value.isPlaying ? controller.pause() : controller.play()),
              IconButton(color: Colors.white, icon: const Icon(Icons.replay_10), onPressed: () => onSeek(-10)),
              IconButton(color: Colors.white, icon: const Icon(Icons.forward_10), onPressed: () => onSeek(10)),
              Expanded(child: Text('${_time(value.position)} / ${_time(value.duration)}', style: const TextStyle(color: Colors.white, fontSize: 12), textAlign: TextAlign.center)),
              IconButton(color: Colors.white, icon: Icon(fullscreen ? Icons.fullscreen_exit : Icons.fullscreen), onPressed: onFullscreen),
            ],
          ),
        ],
      ),
    );
  }
}
