import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/ai_provider.dart';

class AiPosterScreen extends StatefulWidget {
  const AiPosterScreen({super.key});
  @override
  State<AiPosterScreen> createState() => _AiPosterScreenState();
}

class _AiPosterScreenState extends State<AiPosterScreen> {
  Uint8List? bytes;
  String result = '';
  bool loading = false;

  Future<void> pick() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery, imageQuality: 85);
    if (image == null) return;
    final data = await image.readAsBytes();
    if (!mounted) return;
    setState(() => bytes = data);
  }

  Future<void> analyze() async {
    final data = bytes;
    if (data == null) return;
    setState(() => loading = true);
    try {
      final poster = await context.read<AiProvider>().analyzePoster(data);
      if (!mounted) return;
      setState(() {
        result = 'النوع: ${poster.type}\n'
            'الأنواع: ${poster.genres.join('، ')}\n'
            'الجمهور: ${poster.audience}\n'
            'المزاج: ${poster.mood}\n'
            'الألوان: ${poster.colors.join('، ')}\n'
            'الرموز: ${poster.symbols.join('، ')}\n\n'
            '${poster.verdict}';
      });
    } catch (e) {
      if (mounted) setState(() => result = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تحليل البوستر')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: loading ? null : pick,
              icon: const Icon(Icons.image),
              label: const Text('اختيار صورة'),
            ),
            if (bytes != null)
              Expanded(child: Image.memory(bytes!, fit: BoxFit.contain)),
            ElevatedButton(
              onPressed: loading || bytes == null ? null : analyze,
              child: const Text('تحليل'),
            ),
            if (result.isNotEmpty)
              Expanded(
                child: SingleChildScrollView(child: Text(result)),
              ),
          ],
        ),
      ),
    );
  }
}
