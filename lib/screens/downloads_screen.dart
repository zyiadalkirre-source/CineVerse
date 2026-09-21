import 'dart:io';

import 'package:flutter/material.dart';

import '../models/media_item.dart';
import '../services/offline_download_service.dart';
import 'detail_screen.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  final _service = OfflineDownloadService.instance;
  List<MediaItem> _items = [];
  bool _loading = true;
  int _sizeBytes = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await _service.getDownloads();
    final size = await _service.sizeBytes();
    if (!mounted) return;
    setState(() {
      _items = items;
      _sizeBytes = size;
      _loading = false;
    });
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return (bytes / 1024).toStringAsFixed(1) + ' KB';
    if (bytes < 1024 * 1024 * 1024) {
      return (bytes / (1024 * 1024)).toStringAsFixed(1) + ' MB';
    }
    return (bytes / (1024 * 1024 * 1024)).toStringAsFixed(2) + ' GB';
  }

  Future<void> _delete(MediaItem item) async {
    await _service.remove(item);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم حذف «' + item.title + '» من التخزين المحلي.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('تحميلاتي')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: _items.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 120),
                          Icon(Icons.download_for_offline_outlined, size: 72),
                          SizedBox(height: 16),
                          Center(
                            child: Text(
                              'لا توجد عناصر محفوظة دون اتصال بعد.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                          SizedBox(height: 8),
                          Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 28),
                              child: Text(
                                'من صفحة أي فيلم أو مسلسل اختر «حفظ دون اتصال» لحفظ معلوماته وصوره على الجهاز.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(12),
                        children: [
                          Card(
                            child: ListTile(
                              leading: const Icon(Icons.storage_outlined),
                              title: Text(_items.length.toString() + ' عناصر محفوظة'),
                              subtitle: Text('المساحة المستخدمة: ' + _formatBytes(_sizeBytes)),
                            ),
                          ),
                          const SizedBox(height: 10),
                          ..._items.map(
                            (item) => Card(
                              child: ListTile(
                                leading: FutureBuilder<String?>(
                                  future: _service.posterPath(item),
                                  builder: (_, snapshot) {
                                    final path = snapshot.data;
                                    if (path == null) {
                                      return const CircleAvatar(
                                        child: Icon(Icons.movie_outlined),
                                      );
                                    }
                                    return ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(
                                        File(path),
                                        width: 50,
                                        height: 64,
                                        fit: BoxFit.cover,
                                      ),
                                    );
                                  },
                                ),
                                title: Text(
                                  item.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  item.year + ' • ⭐ ' + item.voteAverage.toStringAsFixed(1),
                                ),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DetailScreen(item: item),
                                  ),
                                ),
                                trailing: IconButton(
                                  tooltip: 'حذف',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _delete(item),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
      ),
    );
  }
}
