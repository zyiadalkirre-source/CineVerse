import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/media_provider.dart';
import 'detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final c = TextEditingController();
  Timer? _debounce;
  List results = [];
  List<String> history = [];
  bool loading = false;
  String typeFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final items = await context.read<MediaProvider>().database.getSearchHistory(limit: 12);
    if (mounted) setState(() => history = items);
  }

  void _scheduleSearch(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) return;
    _debounce = Timer(const Duration(milliseconds: 550), go);
  }

  Future<void> go() async {
    final query = c.text.trim();
    if (query.isEmpty) return;

    setState(() {
      loading = true;
      results = [];
    });

    final provider = context.read<MediaProvider>();

    try {
      final found = await provider.search(query, 'ar');
      if (!mounted) return;

      setState(() {
        results = _filter(found);
      });

      await _loadHistory();

      if (results.isEmpty && provider.error != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(provider.error!)),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List _filter(List found) {
    if (typeFilter == 'all') return found;
    return found.where((x) => x.mediaType == typeFilter).toList();
  }

  void _applyFilter(String value) {
    setState(() => typeFilter = value);
    if (c.text.trim().isNotEmpty) {
      go();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MediaProvider>();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('البحث')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: TextField(
                controller: c,
                onChanged: _scheduleSearch,
                onSubmitted: (_) => go(),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'ابحث عن فيلم أو مسلسل أو أنمي',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    onPressed: go,
                    icon: const Icon(Icons.search_rounded),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),

            if (history.isNotEmpty)
              SizedBox(
                height: 42,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  scrollDirection: Axis.horizontal,
                  itemCount: history.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => ActionChip(
                    avatar: const Icon(Icons.history, size: 17),
                    label: Text(
                      history[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: () {
                      c.text = history[i];
                      c.selection = TextSelection.collapsed(
                        offset: c.text.length,
                      );
                      go();
                    },
                  ),
                ),
              ),

            SizedBox(
              height: 48,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                scrollDirection: Axis.horizontal,
                children: [
                  ChoiceChip(
                    label: const Text('الكل'),
                    selected: typeFilter == 'all',
                    onSelected: (_) => _applyFilter('all'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('أفلام'),
                    selected: typeFilter == 'movie',
                    onSelected: (_) => _applyFilter('movie'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('مسلسلات'),
                    selected: typeFilter == 'tv',
                    onSelected: (_) => _applyFilter('tv'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('أنمي'),
                    selected: typeFilter == 'anime',
                    onSelected: (_) => _applyFilter('anime'),
                  ),
                ],
              ),
            ),

            if (provider.lastCorrectedQuery != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'هل تقصد: ${provider.lastCorrectedQuery!}؟ تم تصحيح البحث تلقائياً.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

            if (loading) const LinearProgressIndicator(),

            Expanded(
              child: results.isEmpty && !loading
                  ? const Center(
                      child: Text('اكتب اسم فيلم أو مسلسل أو أنمي للبحث'),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: .62,
                      ),
                      itemCount: results.length,
                      itemBuilder: (_, i) {
                        final x = results[i];
                        return InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DetailScreen(item: x),
                            ),
                          ),
                          child: Column(
                            children: [
                              Expanded(
                                child: x.posterUrl == null
                                    ? const Center(child: Icon(Icons.movie))
                                    : Image.network(
                                        x.posterUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(Icons.broken_image),
                                      ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                x.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
