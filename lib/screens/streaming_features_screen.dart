import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

import '../models/media_item.dart';
import '../providers/media_provider.dart';
import 'clips_screen.dart';
import 'detail_screen.dart';
import 'downloads_screen.dart';
import 'drawer_section_screen.dart';
import 'my_cineverse_screen.dart';
import 'notes_screen.dart';
import 'search_screen.dart';
import 'stats_screen.dart';
import 'latest_updates_screen.dart';
import 'ai_hub_screen.dart';

class StreamingFeaturesScreen extends StatefulWidget {
  const StreamingFeaturesScreen({super.key});

  @override
  State<StreamingFeaturesScreen> createState() => _StreamingFeaturesScreenState();
}

class _StreamingFeaturesScreenState extends State<StreamingFeaturesScreen> {
  final Map<String, bool> _toggles = {
    'autoNext': true,
    'autoTrailer': false,
    'rememberProgress': true,
    'autoFullscreen': false,
    'spoilerShield': true,
    'kidsMode': false,
    'dataSaver': false,
    'wifiOnly': true,
    'smartDownloads': false,
    'reduceMotion': false,
    'hideWatched': false,
  };

  int _nextCountdown = 10;
  int _skipIntro = 10;
  int _skipRecap = 10;
  double _defaultSpeed = 1.0;
  String _profile = 'زياد';

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      for (final key in _toggles.keys) {
        _toggles[key] = prefs.getBool('stream_$key') ?? _toggles[key]!;
      }
      _nextCountdown = prefs.getInt('stream_nextCountdown') ?? 10;
      _skipIntro = prefs.getInt('stream_skipIntro') ?? 10;
      _skipRecap = prefs.getInt('stream_skipRecap') ?? 10;
      _defaultSpeed = prefs.getDouble('stream_defaultSpeed') ?? 1.0;
      _profile = prefs.getString('stream_profile') ?? 'زياد';
    });
  }

  Future<void> _setToggle(String key, bool value) async {
    setState(() => _toggles[key] = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('stream_$key', value);
  }

  Future<void> _setInt(String key, int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, value);
  }

  Future<void> _setSpeed(double value) async {
    setState(() => _defaultSpeed = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('stream_defaultSpeed', value);
  }

  Future<void> _setProfile(String profile) async {
    setState(() => _profile = profile);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('stream_profile', profile);
  }

  Future<void> _pickRandom(BuildContext context) async {
    final provider = context.read<MediaProvider>();
    var items = provider.library;
    if (_toggles['hideWatched'] == true) {
      items = items.where((x) => x.watchStatus != 'watched').toList();
    }
    if (items.isEmpty) {
      _showMessage('المكتبة فارغة حالياً.');
      return;
    }
    final item = items[Random().nextInt(items.length)];
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DetailScreen(item: item)),
    );
  }

  void _showPicker(String title, List<MediaItem> items) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 10),
            ...items.take(20).map(
              (item) => ListTile(
                leading: _Poster(item: item, size: 46),
                title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(item.year + ' • ' + item.mediaType),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => DetailScreen(item: item)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGenres() {
    final provider = context.read<MediaProvider>();
    final genres = <String>{};
    for (final item in provider.library) {
      genres.addAll(item.genres);
    }
    if (genres.isEmpty) {
      _showMessage('لا توجد أنواع مسجلة في مكتبتك بعد.');
      return;
    }
    final sortedGenres = genres.toList()..sort((a, b) => a.compareTo(b));
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: sortedGenres
                .map(
                  (genre) => ActionChip(
                    label: Text(genre),
                    onPressed: () {
                      Navigator.pop(context);
                      final matching = provider.library.where((x) => x.genres.contains(genre)).toList();
                      _showPicker('أعمال: ' + genre, matching);
                    },
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  void _showMoods() {
    const moods = {
      '🧠 ذكي وغامض': ['mystery', 'thriller', 'crime', 'drama'],
      '😂 خفيف ومضحك': ['comedy', 'family'],
      '🔥 حماس وأكشن': ['action', 'adventure', 'war'],
      '❤️ عاطفي': ['romance', 'drama'],
      '👻 رعب': ['horror', 'thriller'],
      '🚀 خيال علمي': ['science fiction', 'sci-fi', 'fantasy'],
    };

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'اختيار حسب المزاج',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            ...moods.entries.map(
              (entry) => ListTile(
                leading: const Icon(Icons.auto_awesome_rounded),
                title: Text(entry.key),
                onTap: () {
                  Navigator.pop(context);
                  final keys = entry.value.map((x) => x.toLowerCase()).toSet();
                  final items = context.read<MediaProvider>().library.where((item) {
                    return item.genres.any((g) => keys.contains(g.toLowerCase()));
                  }).toList();
                  _showPicker(entry.key, items);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _becauseYouWatched() {
    final provider = context.read<MediaProvider>();
    final seeds = provider.library.where(
      (x) => x.lastWatchedSeconds > 0 || x.isFavorite || x.userTaste == 'love',
    ).toList();
    if (seeds.isEmpty) {
      _showMessage('شاهد أو أضف عملاً واحداً أولاً لبناء التوصيات المحلية.');
      return;
    }
    final genres = <String>{};
    for (final seed in seeds.take(4)) {
      genres.addAll(seed.genres);
    }
    final items = provider.library.where((item) {
      if (seeds.any((s) => s.id == item.id && s.mediaType == item.mediaType)) return false;
      return item.genres.any(genres.contains);
    }).toList()
      ..sort((a, b) => b.voteAverage.compareTo(a.voteAverage));
    _showPicker('لأنك شاهدت أعمالاً مشابهة', items);
  }

  void _dailyMix() {
    final items = context.read<MediaProvider>().library.toList()..shuffle();
    _showPicker('Daily Mix • مزيجك اليومي', items);
  }

  void _top10() {
    final items = context.read<MediaProvider>().library.toList()
      ..sort((a, b) {
        final score = b.voteAverage.compareTo(a.voteAverage);
        return score != 0 ? score : b.voteCount.compareTo(a.voteCount);
      });
    _showPicker('Top 10 في مكتبتك', items.take(10).toList());
  }

  void _tonight() {
    final items = context.read<MediaProvider>().library.toList()
      ..sort((a, b) => b.voteAverage.compareTo(a.voteAverage));
    _showPicker('اختيارات السهرة', items.take(5).toList());
  }

  void _shareItem() {
    final items = context.read<MediaProvider>().library;
    if (items.isEmpty) {
      _showMessage('أضف عملاً واحداً على الأقل للمشاركة.');
      return;
    }
    _showPicker('اختر عملاً للمشاركة', items);
  }

  Future<void> _generatePartyCode() async {
    final code = List.generate(6, (_) => Random().nextInt(10)).join();
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Watch Party محلي'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('رمز جلسة محلي جاهز للمشاركة:'),
            const SizedBox(height: 16),
            SelectableText(
              code,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: 8,
              ),
            ),
            const SizedBox(height: 10),
            const Text('تم نسخ الرمز للحافظة. هذه النسخة لا تتطلب خادماً خارجياً.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
          FilledButton.icon(
            onPressed: () async {
              await SharePlus.instance.share(
                ShareParams(text: 'انضم إلى Watch Party في CineVerse. الرمز: $code'),
              );
            },
            icon: const Icon(Icons.share_rounded),
            label: const Text('مشاركة'),
          ),
        ],
      ),
    );
  }

  void _profiles() {
    const profiles = ['زياد', 'سينما', 'الأطفال'];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: profiles.map(
            (profile) => RadioListTile<String>(
              value: profile,
              groupValue: _profile,
              onChanged: (value) {
                if (value == null) return;
                _setProfile(value);
                Navigator.pop(context);
              },
              title: Text(profile),
              secondary: Icon(
                profile == 'الأطفال' ? Icons.child_care_rounded : Icons.person_rounded,
              ),
            ),
          ).toList(),
        ),
      ),
    );
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _open(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  List<_Feature> get _features => [
    _Feature.toggle('تشغيل الحلقة التالية تلقائياً', 'ينتقل للعمل التالي بعد نهاية الحلقة.', Icons.skip_next_rounded, 'autoNext'),
    _Feature.choice('عداد الحلقة التالية', '5 / 10 / 15 / 30 ثانية قبل الانتقال.', Icons.timer_rounded, () => _chooseInt('stream_nextCountdown', _nextCountdown, (v) => setState(() => _nextCountdown = v))),
    _Feature.choice('تخطي المقدمة', 'إعداد زمني لزر التخطي داخل تجربة المشاهدة.', Icons.fast_forward_rounded, () => _chooseInt('stream_skipIntro', _skipIntro, (v) => setState(() => _skipIntro = v))),
    _Feature.choice('تخطي الملخص', 'إعداد مستقل للملخص في بداية الحلقة.', Icons.history_toggle_off_rounded, () => _chooseInt('stream_skipRecap', _skipRecap, (v) => setState(() => _skipRecap = v))),
    _Feature.toggle('تشغيل التريلرات تلقائياً', 'تحكم بسلوك التريلرات على صفحات الاكتشاف.', Icons.play_circle_fill_rounded, 'autoTrailer'),
    _Feature.toggle('تذكّر موضع المشاهدة', 'استكمال الفيلم أو الحلقة من آخر موضع محفوظ.', Icons.bookmark_added_rounded, 'rememberProgress'),
    _Feature.choice('سرعة التشغيل الافتراضية', 'اختيار 0.75× إلى 2×.', Icons.speed_rounded, _chooseSpeed),
    _Feature.toggle('ملء الشاشة تلقائياً', 'يجهز وضع المشاهدة الأفقي عند بدء التشغيل.', Icons.fullscreen_rounded, 'autoFullscreen'),
    _Feature.toggle('حماية من الحرق', 'إخفاء تفاصيل إضافية إلى أن يطلبها المستخدم.', Icons.visibility_off_rounded, 'spoilerShield'),
    _Feature.toggle('وضع الأطفال', 'يفعّل تفضيلات مشاهدة أبسط محلياً.', Icons.child_care_rounded, 'kidsMode'),
    _Feature.toggle('توفير البيانات', 'نمط اقتصادي لتقليل استخدام الشبكة.', Icons.data_saver_on_rounded, 'dataSaver'),
    _Feature.toggle('التنزيل عبر Wi‑Fi فقط', 'يمنع التنزيلات عندما يكون الاتصال محمولاً.', Icons.wifi_rounded, 'wifiOnly'),
    _Feature.toggle('التنزيل الذكي', 'يهيّئ إدارة المحتوى المحفوظ تلقائياً.', Icons.downloading_rounded, 'smartDownloads'),
    _Feature.action('مدير التحميلات', 'عرض وإدارة المحتوى المحفوظ محلياً.', Icons.download_done_rounded, () => _open(const DownloadsScreen())),
    _Feature.action('المكتبة دون اتصال', 'استعرض مكتبتك المحلية حتى مع غياب الشبكة.', Icons.offline_bolt_rounded, () => _showPicker('مكتبة CineVerse', context.read<MediaProvider>().library)),
    _Feature.toggle('تقليل الحركة', 'يقلل المؤثرات البصرية غير الضرورية.', Icons.motion_photos_off_rounded, 'reduceMotion'),
    _Feature.action('اختيار عشوائي', 'دع CineVerse يقرر ماذا تشاهد الآن.', Icons.shuffle_rounded, () => _pickRandom(context)),
    _Feature.action('سهرة الليلة', 'خمس اقتراحات سريعة من مكتبتك.', Icons.nightlight_round, _tonight),
    _Feature.action('استكشف حسب النوع', 'فلترة المكتبة حسب الأنواع المتاحة.', Icons.category_rounded, _showGenres),
    _Feature.action('استكشف حسب المزاج', 'اختيارات محلية حسب مزاجك الآن.', Icons.psychology_alt_rounded, _showMoods),
    _Feature.action('لأنك شاهدت…', 'اقتراحات تعتمد على الأنواع التي تفاعلت معها.', Icons.auto_awesome_rounded, _becauseYouWatched),
    _Feature.action('Daily Mix', 'قائمة يومية عشوائية من مكتبتك.', Icons.queue_music_rounded, _dailyMix),
    _Feature.action('Top 10 محلي', 'أعلى الأعمال تقييماً داخل مكتبتك.', Icons.leaderboard_rounded, _top10),
    _Feature.action('الجديد والساخن', 'انتقل مباشرة إلى آخر التحديثات.', Icons.fiber_new_rounded, () => _open(const LatestUpdatesScreen())),
    _Feature.action('الرائج الآن', 'اكتشف آخر ما يتم تحديثه في المصدر.', Icons.local_fire_department_rounded, () => _open(const LatestUpdatesScreen())),
    _Feature.action('مواعيد الحلقات', 'تابع تواريخ نزول الحلقات والمواسم.', Icons.event_available_rounded, () => _open(const DrawerSectionScreen(section: DrawerSection.episodeDates))),
    _Feature.action('البحث المتقدم', 'البحث والمرشحات وسجل البحث.', Icons.search_rounded, () => _open(const SearchScreen())),
    _Feature.action('Clips', 'مقاطع قصيرة وتريلرات عمودية.', Icons.smart_display_rounded, () => _open(const ClipsScreen())),
    _Feature.action('My CineVerse', 'القائمة والمفضلة والمتابعة في مكان واحد.', Icons.person_rounded, () => _open(const MyCineVerseScreen())),
    _Feature.action('مشاركة عمل', 'شارك عنواناً من مكتبتك عبر النظام.', Icons.share_rounded, _shareItem),
    _Feature.action('Watch Party', 'أنشئ رمز جلسة محلية وشاركه.', Icons.groups_rounded, _generatePartyCode),
    _Feature.action('الملفات الشخصية', 'تبديل ملف محلي بين الملف الشخصي والأطفال.', Icons.account_circle_rounded, _profiles),
  ];

  Future<void> _chooseInt(String key, int current, ValueChanged<int> onChanged) async {
    final value = await showDialog<int>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('اختيار المدة'),
        children: [0, 5, 10, 15, 20, 30].map(
          (v) => SimpleDialogOption(
            onPressed: () => Navigator.pop(context, v),
            child: Row(
              children: [
                Icon(v == current ? Icons.radio_button_checked : Icons.radio_button_off),
                const SizedBox(width: 8),
                Text(v == 0 ? 'إيقاف' : '$v ثانية'),
              ],
            ),
          ),
        ).toList(),
      ),
    );
    if (value == null) return;
    onChanged(value);
    await _setInt(key, value);
    if (!mounted) return;
    setState(() {
      if (key == 'stream_nextCountdown') _nextCountdown = value;
      if (key == 'stream_skipIntro') _skipIntro = value;
      if (key == 'stream_skipRecap') _skipRecap = value;
    });
  }

  Future<void> _chooseSpeed() async {
    final value = await showDialog<double>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('سرعة التشغيل الافتراضية'),
        children: [0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
            .map(
              (speed) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, speed),
                child: Row(
                  children: [
                    Icon(
                      speed == _defaultSpeed
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                    ),
                    const SizedBox(width: 8),
                    Text(speed.toString() + '×'),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
    if (value != null) await _setSpeed(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('مركز ميزات المشاهدة'),
          actions: [
            IconButton(
              tooltip: 'الإحصائيات',
              onPressed: () => _open(const StatsScreen()),
              icon: const Icon(Icons.insights_rounded),
            ),
            IconButton(
              tooltip: 'الملاحظات',
              onPressed: () => _open(const NotesScreen()),
              icon: const Icon(Icons.note_alt_outlined),
            ),
            IconButton(
              tooltip: 'المساعد الذكي',
              onPressed: () => _open(const AiHubScreen()),
              icon: const Icon(Icons.auto_awesome_rounded),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
          children: [
            Card(
              clipBehavior: Clip.antiAlias,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.secondary,
                    ],
                  ),
                ),
                child: DefaultTextStyle(
                  style: const TextStyle(color: Colors.white),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '32 ميزة مشاهدة جاهزة',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'حزمة مستوحاة من أنماط تطبيقات البث الحديثة، ومتكاملة مع مكتبتك الحالية في CineVerse.',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 12),
                      Chip(
                        avatar: const Icon(Icons.person, color: Colors.white),
                        label: Text(_profile, style: const TextStyle(color: Colors.white)),
                        backgroundColor: Colors.white24,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            ..._features.asMap().entries.map(
                  (entry) => _featureTile(entry.key + 1, entry.value),
                ),
          ],
        ),
      ),
    );
  }

  Widget _featureTile(int number, _Feature feature) {
    if (feature.isToggle) {
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: SwitchListTile.adaptive(
          value: _toggles[feature.storageKey] ?? false,
          onChanged: (value) => _setToggle(feature.storageKey!, value),
          secondary: _NumberIcon(number: number, icon: feature.icon),
          title: Text(
            feature.title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(feature.subtitle),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: _NumberIcon(number: number, icon: feature.icon),
        title: Text(
          feature.title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(feature.subtitle),
        trailing: const Icon(Icons.chevron_left_rounded),
        onTap: feature.action,
      ),
    );
  }
}

class _Feature {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? action;
  final String? storageKey;
  final bool isToggle;

  const _Feature._(
    this.title,
    this.subtitle,
    this.icon,
    this.action,
    this.storageKey,
    this.isToggle,
  );

  factory _Feature.toggle(
    String title,
    String subtitle,
    IconData icon,
    String key,
  ) =>
      _Feature._(title, subtitle, icon, null, key, true);

  factory _Feature.action(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback action,
  ) =>
      _Feature._(title, subtitle, icon, action, null, false);

  factory _Feature.choice(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback action,
  ) =>
      _Feature._(title, subtitle, icon, action, null, false);
}

class _NumberIcon extends StatelessWidget {
  const _NumberIcon({required this.number, required this.icon});

  final int number;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          foregroundColor: scheme.onPrimaryContainer,
          child: Icon(icon),
        ),
        Positioned(
          bottom: -4,
          left: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              number.toString(),
              style: TextStyle(
                color: scheme.onPrimary,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster({required this.item, required this.size});

  final MediaItem item;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: item.posterUrl == null
          ? SizedBox(
              width: size,
              height: size * 1.3,
              child: const ColoredBox(
                color: Colors.black12,
                child: Icon(Icons.movie_outlined),
              ),
            )
          : Image.network(
              item.posterUrl!,
              width: size,
              height: size * 1.3,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => SizedBox(
                width: size,
                height: size * 1.3,
                child: const Icon(Icons.broken_image_outlined),
              ),
            ),
    );
  }
}
