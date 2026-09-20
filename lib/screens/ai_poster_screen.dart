import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/errors/ai_error_normalizer.dart';
import '../providers/ai_provider.dart';
import '../services/ai_service.dart';

class AiPosterScreen extends StatefulWidget {
  const AiPosterScreen({super.key});

  @override
  State<AiPosterScreen> createState() => _AiPosterScreenState();
}

class _AiPosterScreenState extends State<AiPosterScreen> {
  Uint8List? _bytes;
  String _result = '';
  String? _error;
  bool _loading = false;

  Future<void> _pick() async {
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 88);
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _result = '';
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = AiErrorNormalizer.normalize(error).message);
    }
  }

  Future<void> _analyze() async {
    final bytes = _bytes;
    if (bytes == null || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _result = '';
    });

    try {
      final poster = await context.read<AiProvider>().analyzePoster(bytes);
      if (!mounted) return;
      setState(() {
        _result = [
          'النوع: ${poster.type}',
          'الأنواع: ${poster.genres.join('، ')}',
          'الجمهور: ${poster.audience}',
          'المزاج: ${poster.mood}',
          'الألوان: ${poster.colors.join('، ')}',
          'معاني الألوان: ${poster.colorMeaning}',
          'الرموز: ${poster.symbols.join('، ')}',
          '',
          poster.verdict,
        ].join('\n');
      });
    } on AiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) setState(() => _error = AiErrorNormalizer.normalize(error).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('تحليل البوستر')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PosterCard(image: _bytes, onPick: _loading ? null : _pick),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loading || _bytes == null ? null : _analyze,
                icon: _loading
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.auto_awesome),
                label: Text(_loading ? 'جارٍ التحليل...' : 'تحليل البوستر'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Card(
                  color: theme.colorScheme.errorContainer,
                  child: ListTile(
                    leading: Icon(Icons.error_outline, color: theme.colorScheme.onErrorContainer),
                    title: Text(_error!, style: TextStyle(color: theme.colorScheme.onErrorContainer)),
                  ),
                ),
              ],
              if (_result.isNotEmpty) ...[
                const SizedBox(height: 14),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: SelectableText(_result, style: const TextStyle(height: 1.6)),
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

class _PosterCard extends StatelessWidget {
  const _PosterCard({required this.image, required this.onPick});

  final Uint8List? image;
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: 0.72,
        child: image == null
            ? InkWell(
                onTap: onPick,
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image_search_outlined, size: 72, color: theme.colorScheme.primary),
                      const SizedBox(height: 18),
                      const Text('ابدأ بتحليل بوستر سينمائي', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      const Text('اختر صورة واضحة من جهازك لمعرفة النوع والمزاج والألوان والرموز والجمهور المستهدف.', textAlign: TextAlign.center),
                      const SizedBox(height: 18),
                      FilledButton.tonalIcon(onPressed: onPick, icon: const Icon(Icons.photo_library_outlined), label: const Text('اختيار صورة')),
                    ],
                  ),
                ),
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(image!, fit: BoxFit.contain),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: FilledButton.tonalIcon(onPressed: onPick, icon: const Icon(Icons.photo_library_outlined), label: const Text('اختيار صورة أخرى')),
                  ),
                ],
              ),
      ),
    );
  }
}
