import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/media_provider.dart';
import 'theme_screen.dart';
import 'api_setup_screen.dart';
import 'account_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool notifyNewEpisodes = false;
  bool saveEpisodeFilter = false;
  bool autoDownload = false;
  int seekSeconds = 10;

  @override
  void initState() {
    super.initState();
    _loadLocalSettings();
  }

  Future<void> _loadLocalSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      notifyNewEpisodes = prefs.getBool('notifyNewEpisodes') ?? false;
      saveEpisodeFilter = prefs.getBool('saveEpisodeFilter') ?? false;
      autoDownload = prefs.getBool('autoDownload') ?? false;
      seekSeconds = prefs.getInt('seekSeconds') ?? 10;
    });
  }

  Future<void> _setBool(String key, bool value) async {
    setState(() {
      switch (key) {
        case 'notifyNewEpisodes':
          notifyNewEpisodes = value;
        case 'saveEpisodeFilter':
          saveEpisodeFilter = value;
        case 'autoDownload':
          autoDownload = value;
      }
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _setSeekSeconds(int value) async {
    setState(() => seekSeconds = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('seekSeconds', value);
  }

  Future<void> _pickSeekSeconds() async {
    final value = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('وقت التقديم'),
        children: [5, 10, 15, 30].map((value) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(context, value),
            child: Text(value == 10 ? '$value (الافتراضي)' : '$value ثانية'),
          );
        }).toList(),
      ),
    );
    if (value != null) await _setSeekSeconds(value);
  }

  Future<void> _pickThemeMode(SettingsProvider sp) async {
    final value = await showDialog<ThemeMode>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('الوضع الليلي'),
        children: [
          _themeOption(context, sp, ThemeMode.system, 'استخدام مظهر النظام'),
          _themeOption(context, sp, ThemeMode.light, 'فاتح'),
          _themeOption(context, sp, ThemeMode.dark, 'داكن'),
        ],
      ),
    );
    if (value != null) await sp.setThemeMode(value);
  }

  Widget _themeOption(
    BuildContext context,
    SettingsProvider sp,
    ThemeMode mode,
    String label,
  ) {
    return SimpleDialogOption(
      onPressed: () => Navigator.pop(context, mode),
      child: Row(
        children: [
          Icon(
            sp.themeMode == mode
                ? Icons.radio_button_checked
                : Icons.radio_button_off,
          ),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }

  Future<void> _shareApp() async {
    await Share.share(
      'جرّب CineVerse لمتابعة الأفلام والمسلسلات وتنظيم مكتبتك السينمائية.',
      subject: 'CineVerse',
    );
  }

  void _showInfoDialog({
    required String title,
    required String message,
  }) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SettingsProvider>();
    final tp = context.watch<ThemeProvider>();
    final scheme = Theme.of(context).colorScheme;

    final themeSubtitle = switch (sp.themeMode) {
      ThemeMode.system => 'استخدام مظهر النظام',
      ThemeMode.light => 'الوضع الفاتح',
      ThemeMode.dark => 'الوضع الداكن',
    };

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'رجوع',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('الاعدادات'),
        ),
        body: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 28),
          children: [
            _sectionTitle(context, 'العام'),

            SwitchListTile(
              value: notifyNewEpisodes,
              onChanged: (value) => _setBool('notifyNewEpisodes', value),
              title: const Text('تنبيه بجميع الحلقات الجديدة'),
              subtitle: const Text(
                'عند تفعيل هذا الخيار سوف يأتي التنبيه مرتين للانميات التي قمت باضافتها للمفضلة',
              ),
            ),

            SwitchListTile(
              value: saveEpisodeFilter,
              onChanged: (value) => _setBool('saveEpisodeFilter', value),
              title: const Text('حفظ فلتر الحلقات'),
            ),

            SwitchListTile(
              value: autoDownload,
              onChanged: (value) => _setBool('autoDownload', value),
              title: const Text('التحميل التلقائي عن طريق ADM'),
            ),

            _sectionTitle(context, 'المشغل'),

            ListTile(
              leading: const Icon(Icons.play_circle_outline_rounded),
              title: const Text('المشغل الافتراضي'),
              subtitle: const Text('المشغل السريع'),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: () => _showInfoDialog(
                title: 'المشغل الافتراضي',
                message:
                    'المشغل الحالي: المشغل السريع. يمكن ربط مشغلات إضافية لاحقاً.',
              ),
            ),

            ListTile(
              leading: const Icon(Icons.forward_10_rounded),
              title: const Text('وقت التقديم'),
              subtitle: Text(
                seekSeconds == 10
                    ? '(الافتراضي) 10'
                    : '$seekSeconds ثانية',
              ),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: _pickSeekSeconds,
            ),

            _sectionTitle(context, 'المظهر'),

            ListTile(
              leading: const Icon(Icons.dark_mode_outlined),
              title: const Text('الوضع الليلي'),
              subtitle: Text(themeSubtitle),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: () => _pickThemeMode(sp),
            ),

            ListTile(
              leading: Icon(Icons.palette_outlined, color: tp.effectiveSeed),
              title: const Text('المظهر الداكن'),
              subtitle: const Text('أزرق غامق (الافتراضي)'),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ThemeScreen()),
              ),
            ),

            _sectionTitle(context, 'اخرى'),

            ListTile(
              leading: const Icon(Icons.block_rounded),
              title: const Text('الكلمات المحجوبة'),
              subtitle: const Text(
                'لن يتم عرض التعليقات التي تحتوي على الكلمات المحجوبة',
              ),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: () => _showInfoDialog(
                title: 'الكلمات المحجوبة',
                message:
                    'يمكن إضافة نظام كلمات محجوبة للتعليقات عند تفعيل التعليقات داخل التطبيق.',
              ),
            ),

            ListTile(
              leading: const Icon(Icons.emoji_events_outlined),
              title: const Text('أبرز المساهمين'),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: () => _showInfoDialog(
                title: 'أبرز المساهمين',
                message: 'سيظهر هنا ترتيب أبرز المساهمين في CineVerse.',
              ),
            ),

            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('مشاركة التطبيق'),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: _shareApp,
            ),

            ListTile(
              leading: const Icon(Icons.warning_amber_rounded),
              title: const Text('اخلاء المسؤولية'),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: () => _showInfoDialog(
                title: 'اخلاء المسؤولية',
                message:
                    'CineVerse تطبيق لتنظيم واكتشاف المحتوى. توفر المحتوى ومعلوماته يعتمد على الخدمات والمصادر المرتبطة بالتطبيق.',
              ),
            ),

            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('حول'),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: () => showAboutDialog(
                context: context,
                applicationName: 'CineVerse',
                applicationVersion: '1.0.0',
                applicationIcon: Icon(
                  Icons.movie_filter_rounded,
                  color: scheme.primary,
                ),
                children: const [
                  Text(
                    'تطبيق CineVerse لإدارة ومتابعة الأفلام والمسلسلات مع أدوات اكتشاف وميزات ذكية.',
                  ),
                ],
              ),
            ),

            const Divider(height: 32),

            Card(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              child: ListTile(
                leading: const Icon(Icons.account_circle_rounded),
                title: const Text('حساب Google'),
                subtitle: const Text(
                  'تسجيل الدخول ومزامنة مكتبتك عبر الأجهزة',
                ),
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AccountScreen(),
                  ),
                ),
              ),
            ),

            Card(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: ListTile(
                leading: const Icon(Icons.key_rounded),
                title: const Text('إعداد مفاتيح API'),
                subtitle: const Text('TMDB و Gemini'),
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ApiSetupScreen(),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 18),

            const Center(
              child: Text(
                'CineVerse 1.0.0',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
