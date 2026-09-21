import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/ai_provider.dart';
import '../services/ai_service.dart';

class AiMoodScreen extends StatefulWidget {
  const AiMoodScreen({super.key});

  @override
  State<AiMoodScreen> createState() => _AiMoodScreenState();
}

class _AiMoodScreenState extends State<AiMoodScreen> {
  final _controller = TextEditingController();
  String _result = '';
  String? _error;
  bool _loading = false;

  Future<void> _analyze() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _loading) return;

    setState(() {
      _loading = true;
      _result = '';
      _error = null;
    });

    try {
      final mood = await context.read<AiProvider>().classifyMood(text);
      if (!mounted) return;
      setState(() {
        _result = [
          mood.detectedMood,
          mood.explanation,
          '',
          'الأنواع المناسبة: ${mood.genres.join('، ')}',
          'الأنواع الأقل ملاءمة: ${mood.avoidGenres.join('، ')}',
          '',
          'أفلام: ${mood.movies.join('، ')}',
          'أنمي: ${mood.anime.join('، ')}',
        ].join('\n');
      });
    } on AiServiceException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'حدث خطأ أثناء تحليل مزاجك. حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('حسب مزاجي')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Icon(Icons.psychology_outlined, size: 58),
                      const SizedBox(height: 12),
                      const Text(
                        'احكِ لـ CineVerse عن مزاجك',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'اكتب الشعور أو الأجواء التي تبحث عنها، وسنحللها ونقترح لك أعمالاً مناسبة.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _controller,
                        maxLines: 4,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          hintText: 'مثلاً: بدي شيء غامض ومشوق الليلة',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _loading ? null : _analyze,
                  icon: _loading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: Text(_loading ? 'جارٍ التحليل...' : 'حلل مزاجي'),
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
