import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import '../models/media_item.dart';
import '../providers/media_provider.dart';
import '../services/video_source_service.dart';
import 'package:provider/provider.dart';

class WatchScreen extends StatefulWidget {
  final MediaItem item;
  final String title;
  final String episodeName;
  final int season;
  final int episode;
  final String? videoUrl;
  const WatchScreen({super.key, required this.item, required this.title, required this.episodeName, required this.season, required this.episode, required this.videoUrl});
  @override State<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends State<WatchScreen> {
  VideoPlayerController? _controller;
  SharedPreferences? _prefs;
  late final MediaProvider _mediaProvider;
  bool _initializing = false;
  bool _fullscreen = false;
  String? _error;
  int _lastSyncedSecond = -1;
  String get _progressKey => 'watch_progress_${widget.title}_${widget.season}_${widget.episode}';

  @override void initState() { super.initState(); _mediaProvider = context.read<MediaProvider>(); _prepare(); }
  Future<void> _prepare() async {
    _prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final episodeSaved = await _mediaProvider.getEpisodeProgress(
      item: widget.item,
      season: widget.season,
      episode: widget.episode,
    );
    final saved = episodeSaved?['position_seconds'] is int
        ? episodeSaved!['position_seconds'] as int
        : (_prefs?.getInt(_progressKey) ?? (widget.item.lastWatchedSeason == widget.season && widget.item.lastWatchedEpisode == widget.episode ? widget.item.lastWatchedSeconds : 0));
    String? resolvedUrl = widget.videoUrl?.trim();
    if (resolvedUrl == null || resolvedUrl.isEmpty) {
      resolvedUrl = await VideoSourceService.instance.resolve(
        item: widget.item,
        season: widget.season,
        episode: widget.episode,
      );
    }
    if (resolvedUrl == null || resolvedUrl.isEmpty) {
      if (mounted) setState(() => _error = 'لا يوجد مصدر مشاهدة فعلي لهذه الحلقة حالياً.');
      return;
    }
    final uri = Uri.tryParse(resolvedUrl);
    if (uri == null || !uri.hasScheme) { if (mounted) setState(() => _error = 'رابط المشاهدة غير صالح.'); return; }
    setState(() => _initializing = true);
    try {
      final c = VideoPlayerController.networkUrl(uri);
      _controller = c;
      await c.initialize();
      final pos = Duration(seconds: saved);
      if (pos > Duration.zero && pos < c.value.duration) await c.seekTo(pos);
      c.addListener(_savePosition);
      if (mounted) setState(() => _initializing = false);
    } catch (_) {
      _controller?.dispose(); _controller = null;
      if (mounted) setState(() { _initializing = false; _error = 'تعذر تشغيل مصدر الفيديو. تأكد أن الرابط يعمل ويدعم الفيديو.'; });
    }
  }
  Future<void> _savePosition() async {
    final c = _controller; final p = _prefs;
    if (c == null || p == null || !c.value.isInitialized) return;
    final seconds = c.value.position.inSeconds;
    if (seconds > 0) {
      await p.setInt(_progressKey, seconds);
      if (mounted && (seconds - _lastSyncedSecond).abs() >= 5) {
        _lastSyncedSecond = seconds;
        await _mediaProvider.saveWatchProgress(
          widget.item,
          seconds: seconds,
          season: widget.season,
          episode: widget.episode,
          episodeName: widget.episodeName,
          durationSeconds: c.value.duration.inSeconds,
        );
      }
    }
  }
  Future<void> _seek(int seconds) async {
    final c = _controller; if (c == null || !c.value.isInitialized) return;
    var target = c.value.position + Duration(seconds: seconds);
    if (target < Duration.zero) target = Duration.zero;
    if (target > c.value.duration) target = c.value.duration;
    await c.seekTo(target);
  }
  Future<void> _fullscreenToggle() async {
    _fullscreen = !_fullscreen;
    if (_fullscreen) {
      await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    if (mounted) setState(() {});
  }
  @override void dispose() { _savePosition(); _controller?.removeListener(_savePosition); _controller?.dispose(); SystemChrome.setPreferredOrientations([]); SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge); super.dispose(); }
  String _time(Duration d) { final h=d.inHours; final m=d.inMinutes.remainder(60).toString().padLeft(2,'0'); final s=d.inSeconds.remainder(60).toString().padLeft(2,'0'); return h>0 ? h.toString()+':'+m+':'+s : m+':'+s; }
  @override Widget build(BuildContext context) {
    final c=_controller; final ready=c!=null && c.value.isInitialized;
    return Scaffold(backgroundColor: Colors.black, appBar: _fullscreen ? null : AppBar(title: Text('${widget.title} — م${widget.season} ح${widget.episode}')), body: SafeArea(top:!_fullscreen,bottom:!_fullscreen,child:Center(child: ready ? AspectRatio(aspectRatio:c.value.aspectRatio==0?16/9:c.value.aspectRatio,child:Stack(alignment:Alignment.bottomCenter,children:[VideoPlayer(c),_Controls(controller:c,format:_time,onSeek:_seek,onFullscreen:_fullscreenToggle,fullscreen:_fullscreen)])) : _Status(loading:_initializing,error:_error,episodeName:widget.episodeName))));
  }
}

class _Status extends StatelessWidget {
  final bool loading; final String? error; final String episodeName;
  const _Status({required this.loading, required this.error, required this.episodeName});
  @override Widget build(BuildContext context) {
    if (loading) return const Column(mainAxisSize:MainAxisSize.min,children:[CircularProgressIndicator(),SizedBox(height:12),Text('جاري تجهيز المشغل...',style:TextStyle(color:Colors.white))]);
    return Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.video_library_outlined,color:Colors.white70,size:64),const SizedBox(height:16),Text(error??'لا يوجد مصدر مشاهدة',textAlign:TextAlign.center,style:const TextStyle(color:Colors.white,fontSize:16)),const SizedBox(height:10),Text(episodeName,textAlign:TextAlign.center,style:const TextStyle(color:Colors.white60)),const SizedBox(height:12),const Text('CineVerse لن يضع رابطاً وهمياً. يجب أن يصل رابط فيديو قانوني وموثوق من مزود المحتوى أو من خدمة الباك-إند.',textAlign:TextAlign.center,style:TextStyle(color:Colors.white54,fontSize:12))]));
  }
}

class _Controls extends StatelessWidget {
  final VideoPlayerController controller; final String Function(Duration) format; final Future<void> Function(int) onSeek; final Future<void> Function() onFullscreen; final bool fullscreen;
  const _Controls({required this.controller,required this.format,required this.onSeek,required this.onFullscreen,required this.fullscreen});
  @override Widget build(BuildContext context) {
    final v=controller.value;
    return Container(padding:const EdgeInsets.fromLTRB(8,40,8,6),decoration:const BoxDecoration(gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[Colors.transparent,Colors.black87])),child:Column(mainAxisAlignment:MainAxisAlignment.end,children:[
      VideoProgressIndicator(controller,allowScrubbing:true,padding:const EdgeInsets.symmetric(vertical:6),colors:const VideoProgressColors(playedColor:Colors.red,bufferedColor:Colors.white38,backgroundColor:Colors.white24)),
      Row(children:[IconButton(color:Colors.white,icon:Icon(v.isPlaying?Icons.pause:Icons.play_arrow),onPressed:()=>v.isPlaying?controller.pause():controller.play()),IconButton(color:Colors.white,icon:const Icon(Icons.replay_10),onPressed:()=>onSeek(-10)),IconButton(color:Colors.white,icon:const Icon(Icons.forward_10),onPressed:()=>onSeek(10)),Expanded(child:Text(format(v.position)+' / '+format(v.duration),style:const TextStyle(color:Colors.white,fontSize:12),textAlign:TextAlign.center)),IconButton(color:Colors.white,icon:Icon(fullscreen?Icons.fullscreen_exit:Icons.fullscreen),onPressed:onFullscreen)]),
    ]));
  }
}