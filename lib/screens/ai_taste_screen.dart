import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/ai_provider.dart';
import '../providers/media_provider.dart';
import '../services/ai_service.dart';

class AiTasteScreen extends StatefulWidget {
  const AiTasteScreen({super.key});

  @override
  State<AiTasteScreen> createState() => _AiTasteScreenState();
}

class _AiTasteScreenState extends State<AiTasteScreen> {
  String _result = '';
  String? _error;
  bool _loading = false;

  Future<void> _analyze() async {
    final library = context.read<MediaProvider>().library;
    if (library.isEmpty || _loading) return;

    setState(() {
      _loading = true;
      _result = '';
      _error = null;
    });

    try {
      final taste = await context.read<AiProvider>().analyzeTaste(library);
      if (!mounted) return;
      setState(() {
        _result = [
          taste.archetype,
          taste.personality,
          '',
          'أنماطك: ${taste.patterns.join('، ')}',
          '',
          'نقاط القوة: ${taste.strengths}',
          '',
          'النقاط العمياء: ${taste.blindSpots}',
          '',
          'الأنواع المفضلة: ${taste.topGenres.join('، ')}',
          'مجالات التجربة: ${taste.avoidedGenres.join('، ')}',
          '',
          'اقتراح: ${taste.recommendation}',
        ].join('\n');
      });
    } on AiServiceException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'حدث خطأ أثناء تحليل مكتبتك. حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<MediaProvider>().library;

    return Scaffold(
      appBar: AppBar(title: const Text('تحليل ذوقي')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    children: [
                      const Icon(Icons.auto_awesome_outlined, size: 64),
                      const SizedBox(height: 12),
                      const Text(
                        'تحليل ذوقك السينمائي',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        library.isEmpty
                            ? 'أضف بعض الأفلام أو المسلسلات إلى مكتبتك أولاً حتى يكون التحليل مفيداً.'
                            : 'سيحلل CineVerse الأنماط والأنواع الموجودة في مكتبتك ويعطيك صورة منظمة عن ذوقك.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: library.isEmpty || _loading ? null : _analyze,
                  icon: _loading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.analytics_outlined),
                  label: Text(_loading ? 'جارٍ التحليل...' : 'حلل مكتبتي'),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                _ErrorCard(message: _error!),
              ],
              if (_result.isNotEmpty) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: SelectableText(_result, style: const TextStyle(height: 1.55)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: ListTile(
          leading: const Icon(Icons.cloud_off_outlined),
          title: Text(message),
        ),
      );
}
