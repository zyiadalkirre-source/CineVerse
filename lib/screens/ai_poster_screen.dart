import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

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
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image == null) return;

      final data = await image.readAsBytes();
      if (!mounted) return;

      setState(() {
        _bytes = data;
        _result = '';
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'تعذر اختيار الصورة. حاول مرة أخرى.');
      }
    }
  }

  Future<void> _analyze() async {
    final data = _bytes;
    if (data == null || _loading) return;

    setState(() {
      _loading = true;
      _error = null;
      _result = '';
    });

    try {
      final poster = await context.read<AiProvider>().analyzePoster(data);
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
    } on AiServiceException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'حدث خطأ أثناء تحليل البوستر. حاول مرة أخرى.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تحليل البوستر')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          child: Column(
            children: [
              _PosterEmptyState(
                hasImage: _bytes != null,
                onPick: _loading ? null : _pick,
                image: _bytes,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _loading || _bytes == null ? null : _analyze,
                  icon: _loading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: Text(_loading ? 'جارٍ التحليل...' : 'تحليل البوستر'),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                _ErrorCard(message: _error!),
              ],
              if (_result.isNotEmpty) ...[
                const SizedBox(height: 14),
                _ResultCard(result: _result),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PosterEmptyState extends StatelessWidget {
  const _PosterEmptyState({
    required this.hasImage,
    required this.onPick,
    required this.image,
  });

  final bool hasImage;
  final VoidCallback? onPick;
  final Uint8List? image;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPick,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 300, maxHeight: 520),
          child: image == null
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.image_search_outlined, size: 72),
                        SizedBox(height: 16),
                        Text(
                          'حلّل أي بوستر بالذكاء الاصطناعي',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'اختر صورة واضحة من جهازك لمعرفة النوع والمزاج والألوان والرموز والجمهور المستهدف.',
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 18),
                        Text('JPG أو PNG • صورة واضحة أفضل للنتيجة'),
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
                      child: FilledButton.tonalIcon(
                        onPressed: onPick,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('اختيار صورة أخرى'),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final String result;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: SelectableText(
          result,
          style: const TextStyle(height: 1.55),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: ListTile(
        leading: Icon(
          Icons.cloud_off_outlined,
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
        title: Text(
          message,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
        ),
      ),
    );
  }
}
