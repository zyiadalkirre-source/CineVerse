import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ai_provider.dart';

class AiMoodScreen extends StatefulWidget {
  const AiMoodScreen({super.key});
  @override
  State<AiMoodScreen> createState() => _AiMoodScreenState();
}

class _AiMoodScreenState extends State<AiMoodScreen> {
  final controller = TextEditingController();
  String result = '';
  bool loading = false;

  Future<void> analyze() async {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    setState(() => loading = true);
    try {
      final mood = await context.read<AiProvider>().classifyMood(text);
      if (!mounted) return;
      setState(() {
        result = '${mood.detectedMood}\n${mood.explanation}\n\n'
            'أفلام: ${mood.movies.join('، ')}\n'
            'أنمي: ${mood.anime.join('، ')}';
      });
    } catch (e) {
      if (mounted) setState(() => result = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('حسب مزاجي')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'مثلاً: بدي شيء غامض ومشوق الليلة',
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: loading ? null : analyze,
              child: const Text('حلل مزاجي'),
            ),
            if (loading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
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
