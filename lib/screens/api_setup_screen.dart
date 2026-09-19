import 'package:flutter/material.dart';
import '../core/api_config.dart';

class ApiSetupScreen extends StatefulWidget {
  const ApiSetupScreen({super.key});
  @override State<ApiSetupScreen> createState() => _ApiSetupScreenState();
}
class _ApiSetupScreenState extends State<ApiSetupScreen> {
  final tmdb = TextEditingController();
  final gemini = TextEditingController();
  bool saving = false;
  @override void initState() { super.initState(); tmdb.text = ApiConfig.tmdbKey; gemini.text = ApiConfig.geminiKey; }
  @override void dispose() { tmdb.dispose(); gemini.dispose(); super.dispose(); }
  Future<void> save() async {
    setState(() => saving = true);
    await ApiConfig.save(tmdb: tmdb.text, gemini: gemini.text);
    if (!mounted) return;
    setState(() => saving = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ مفاتيح API بأمان')));
  }
  Widget field(String label, TextEditingController c) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextField(controller: c, obscureText: true, decoration: InputDecoration(labelText: label, prefixIcon: const Icon(Icons.key))),
  );
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('إعداد API')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      const Text('يمكنك إدخال المفاتيح بدون تعديل ملفات المشروع. تُحفظ في التخزين الآمن للجهاز.'),
      const SizedBox(height: 20),
      field('TMDB API Key', tmdb),
      field('Gemini API Key', gemini),
      FilledButton.icon(onPressed: saving ? null : save, icon: const Icon(Icons.save), label: Text(saving ? 'جارٍ الحفظ...' : 'حفظ المفاتيح')),
    ]),
  );
}