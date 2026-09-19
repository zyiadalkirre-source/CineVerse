import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ai_provider.dart';
import '../providers/media_provider.dart';

class AiTasteScreen extends StatefulWidget {
  const AiTasteScreen({super.key});
  @override
  State<AiTasteScreen> createState() => _AiTasteScreenState();
}

class _AiTasteScreenState extends State<AiTasteScreen> {
  String result = '';
  bool loading = false;

  Future<void> analyze() async {
    setState(() => loading = true);
    try {
      final library = context.read<MediaProvider>().library;
      final taste = await context.read<AiProvider>().analyzeTaste(library);
      if (!mounted) return;
      setState(() {
        result = '${taste.archetype}\n${taste.personality}\n\n'
            'أنماطك: ${taste.patterns.join('، ')}\n\n'
            'نقاط القوة: ${taste.strengths}\n\n'
            'مجالات التجربة: ${taste.avoidedGenres.join('، ')}\n\n'
            'اقتراح: ${taste.recommendation}';
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
      appBar: AppBar(title: const Text('تحليل ذوقي')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: loading ? null : analyze,
              child: const Text('حلل مكتبتي'),
            ),
            if (loading) const CircularProgressIndicator(),
            if (result.isNotEmpty)
              Expanded(
                child: SingleChildScrollView(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(result),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
