import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/media_item.dart';
import '../providers/ai_provider.dart';
import '../providers/media_provider.dart';
import '../services/ai_service.dart';

class AiToolsScreen extends StatefulWidget {
  const AiToolsScreen({super.key});

  @override
  State<AiToolsScreen> createState() => _AiToolsScreenState();
}

class _AiToolsScreenState extends State<AiToolsScreen> {
  String result = '';
  bool loading = false;

  Future<void> _run(Future<String> Function() action) async {
    setState(() {
      loading = true;
      result = '';
    });
    try {
      final value = await action();
      if (mounted) setState(() => result = value);
    } on AiServiceException catch (e) {
      if (mounted) setState(() => result = e.message);
    } catch (_) {
      if (mounted) setState(() => result = 'حدث خطأ أثناء تنفيذ أداة الذكاء الاصطناعي. حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  MediaItem _item(String title) => MediaItem(
        id: 0,
        title: title.trim(),
        overview: '',
        voteAverage: 0,
        mediaType: 'movie',
      );

  Future<String?> _ask(String title, String hint, {int maxLines = 1}) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: maxLines,
          autofocus: true,
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('تشغيل'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  Future<void> _showCompare() async {
    final first = await _ask('العمل الأول', 'مثلاً: Inception');
    if (first == null || first.isEmpty) return;
    if (!mounted) return;
    final second = await _ask('العمل الثاني', 'مثلاً: Interstellar');
    if (second == null || second.isEmpty) return;
    if (!mounted) return;

    await _run(() => context.read<AiProvider>().compare(
          _item(first),
          _item(second),
        ));
  }

  Future<void> _showRatings() async {
    final title = await _ask('تحليل التقييمات', 'اسم الفيلم أو المسلسل');
    if (title == null || title.isEmpty) return;
    if (!mounted) return;
    final imdb = await _ask('IMDb', 'مثلاً 8.4');
    if (!mounted) return;
    final rotten = await _ask('Rotten Tomatoes', 'مثلاً 91%');
    if (!mounted) return;
    final meta = await _ask('Metacritic', 'مثلاً 78');
    if (!mounted) return;

    await _run(() => context.read<AiProvider>().analyzeRatings(
          title,
          imdb: imdb ?? '',
          rottenTomatoes: rotten ?? '',
          metacritic: meta ?? '',
        ));
  }

  Future<void> _showAdaptation() async {
    final source = await _ask('العمل الأصلي', 'مثلاً: رواية Dune');
    if (source == null || source.isEmpty) return;
    if (!mounted) return;
    final adaptation = await _ask('الاقتباس', 'مثلاً: Dune 2021');
    if (adaptation == null || adaptation.isEmpty) return;
    if (!mounted) return;

    await _run(
      () => context.read<AiProvider>().adaptationCompare(source, adaptation),
    );
  }

  Future<void> _showTitleAction(
    String dialogTitle,
    Future<String> Function(MediaItem item) action,
  ) async {
    final title = await _ask(dialogTitle, 'اسم الفيلم أو المسلسل أو الأنمي');
    if (title == null || title.isEmpty) return;
    await _run(() => action(_item(title)));
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<MediaProvider>().library;

    return Scaffold(
      appBar: AppBar(title: const Text('أدوات AI المتقدمة')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'ميزات إضافية للمساعد الذكي',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'ميزات كانت مبرمجة داخل الخدمة وتم ربطها الآن بالواجهة.',
          ),
          const SizedBox(height: 16),
          _section('تحليل ومقارنة', [
            _tile(
              Icons.compare_arrows,
              'مقارنة عملين',
              'قارن عملين بشكل منظم',
              _showCompare,
            ),
            _tile(
              Icons.auto_stories,
              'مقارنة اقتباس',
              'قارن العمل الأصلي مع اقتباسه',
              _showAdaptation,
            ),
            _tile(
              Icons.star_border,
              'تحليل التقييمات',
              'حلل IMDb وRotten Tomatoes وMetacritic',
              _showRatings,
            ),
          ]),
          _section('أداة العمل', [
            _tile(
              Icons.theater_comedy,
              'شرح النهاية',
              'تحليل النهاية مع تنبيه للحرق',
              () => _showTitleAction(
                'شرح النهاية',
                context.read<AiProvider>().explainEnding,
              ),
            ),
            _tile(
              Icons.family_restroom,
              'هل يناسب العائلة؟',
              'ملخص ملاءمة المحتوى',
              () => _showTitleAction(
                'ملاءمة العائلة',
                context.read<AiProvider>().familyCheck,
              ),
            ),
            _tile(
              Icons.quiz,
              'اختبار ذكي',
              'إنشاء اختبار قصير عن العمل',
              () => _showTitleAction(
                'اختبار ذكي',
                context.read<AiProvider>().generateQuiz,
              ),
            ),
            _tile(
              Icons.local_offer_outlined,
              'وسوم تلقائية',
              'اقتراح وسوم مفيدة للعمل',
              () => _showTitleAction(
                'وسوم تلقائية',
                context.read<AiProvider>().autoTags,
              ),
            ),
          ]),
          _section('البحث والأفكار', [
            _tile(
              Icons.playlist_add,
              'قائمة مواضيعية',
              'أنشئ قائمة حسب موضوع أو فكرة',
              () async {
                final theme =
                    await _ask('قائمة مواضيعية', 'مثلاً: أفلام سفر عبر الزمن');
                if (theme == null || theme.isEmpty) return;
                await _run(() => context.read<AiProvider>().themedList(theme));
              },
            ),
            _tile(
              Icons.manage_search,
              'تعرّف من وصف',
              'حاول معرفة العمل من وصف ناقص',
              () async {
                final description = await _ask(
                  'تعرّف من وصف',
                  'اكتب ما تتذكره عن الفيلم أو الأنمي...',
                  maxLines: 5,
                );
                if (description == null || description.isEmpty) return;
                await _run(
                  () => context
                      .read<AiProvider>()
                      .identifyFromDescription(description),
                );
              },
            ),
            _tile(
              Icons.screenshot_monitor,
              'تعرّف من لقطة',
              'أدخل وصف اللقطة للحصول على احتمالات',
              () async {
                final description = await _ask(
                  'تعرّف من لقطة',
                  'صف ما يظهر في اللقطة...',
                  maxLines: 5,
                );
                if (description == null || description.isEmpty) return;
                await _run(
                  () => context.read<AiProvider>().screenshotIdentify(
                        description,
                      ),
                );
              },
            ),
          ]),
          _section('مكتبتي', [
            _tile(
              Icons.psychology_alt,
              'منطقة راحتي',
              library.isEmpty
                  ? 'أضف أعمالاً للمكتبة أولاً'
                  : 'حلل الأنواع التي أميل إليها',
              library.isEmpty
                  ? null
                  : () => _run(
                        () => context.read<AiProvider>().comfortZone(library),
                      ),
            ),
          ]),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (result.isNotEmpty) ...[
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(result),
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _tile(
    IconData icon,
    String title,
    String subtitle,
    Future<void> Function()? onTap,
  ) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: loading ? null : onTap,
      ),
    );
  }
}
