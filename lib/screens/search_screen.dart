import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/media_provider.dart';
import 'detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final c = TextEditingController();
  List results = [];
  bool loading = false;

  Future<void> go() async {
    final query = c.text.trim();
    if (query.isEmpty) return;
    setState(() { loading = true; results = []; });
    final provider = context.read<MediaProvider>();
    try {
      results = await provider.search(query, 'ar');
      if (mounted && results.isEmpty && provider.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.error!)));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override void dispose() { c.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) {
    final provider = context.watch<MediaProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('البحث')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: TextField(
            controller: c,
            onSubmitted: (_) => go(),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'ابحث عن فيلم أو مسلسل أو أنمي',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(onPressed: go, icon: const Icon(Icons.arrow_forward)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        if (provider.lastCorrectedQuery != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                'هل تقصد: ' + provider.lastCorrectedQuery! + '؟ تم تصحيح البحث تلقائياً.',
                style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        if (loading) const LinearProgressIndicator(),
        Expanded(
          child: results.isEmpty && !loading
              ? const Center(child: Text('اكتب اسم فيلم أو مسلسل للبحث'))
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: .62),
                  itemCount: results.length,
                  itemBuilder: (_, i) {
                    final x = results[i];
                    return InkWell(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailScreen(item: x))),
                      child: Column(children: [
                        Expanded(
                          child: x.posterUrl == null
                              ? const Center(child: Icon(Icons.movie))
                              : Image.network(x.posterUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image)),
                        ),
                        const SizedBox(height: 4),
                        Text(x.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ]),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
