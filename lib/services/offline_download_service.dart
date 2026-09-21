import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/media_item.dart';

class OfflineDownloadService {
  OfflineDownloadService._();
  static final instance = OfflineDownloadService._();

  Future<Directory> _root() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'cineverse_offline'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _key(MediaItem item) => item.mediaType + '_' + item.id.toString();

  Future<Directory> _itemDir(MediaItem item) async {
    final root = await _root();
    final dir = Directory(p.join(root.path, _key(item)));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<bool> isDownloaded(MediaItem item) async {
    final dir = await _itemDir(item);
    return File(p.join(dir.path, 'media.json')).exists();
  }

  Future<void> download(
    MediaItem item, {
    void Function(double progress)? onProgress,
  }) async {
    final dir = await _itemDir(item);
    onProgress?.call(0.05);

    final payload = {
      ...item.toJson(),
      'offline_saved_at': DateTime.now().toUtc().toIso8601String(),
    };
    await File(p.join(dir.path, 'media.json')).writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
    );
    onProgress?.call(0.35);

    final client = http.Client();
    try {
      await _downloadImage(
        client,
        item.posterUrl,
        File(p.join(dir.path, 'poster.jpg')),
      );
      onProgress?.call(0.70);

      await _downloadImage(
        client,
        item.backdropUrl,
        File(p.join(dir.path, 'backdrop.jpg')),
      );
      onProgress?.call(1);
    } finally {
      client.close();
    }
  }

  Future<void> _downloadImage(
    http.Client client,
    String? url,
    File destination,
  ) async {
    if (url == null || url.trim().isEmpty) return;

    try {
      final response = await client
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        await destination.writeAsBytes(response.bodyBytes, flush: true);
      }
    } catch (_) {
      // Metadata remains available even when artwork download fails.
    }
  }

  Future<List<MediaItem>> getDownloads() async {
    final root = await _root();
    final result = <MediaItem>[];
    if (!await root.exists()) return result;

    await for (final entity in root.list()) {
      if (entity is! Directory) continue;
      final file = File(p.join(entity.path, 'media.json'));
      if (!await file.exists()) continue;

      try {
        final data = jsonDecode(await file.readAsString());
        if (data is Map) {
          final item = MediaItem.fromJson(Map<String, dynamic>.from(data));
          if (item.id > 0) result.add(item);
        }
      } catch (_) {}
    }

    result.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return result;
  }

  Future<String?> posterPath(MediaItem item) async {
    final dir = await _itemDir(item);
    final file = File(p.join(dir.path, 'poster.jpg'));
    return await file.exists() ? file.path : null;
  }

  Future<String?> backdropPath(MediaItem item) async {
    final dir = await _itemDir(item);
    final file = File(p.join(dir.path, 'backdrop.jpg'));
    return await file.exists() ? file.path : null;
  }

  Future<void> remove(MediaItem item) async {
    final root = await _root();
    final dir = Directory(p.join(root.path, _key(item)));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  Future<int> sizeBytes() async {
    final root = await _root();
    if (!await root.exists()) return 0;

    var total = 0;
    await for (final entity in root.list(recursive: true)) {
      if (entity is File) {
        try {
          total += await entity.length();
        } catch (_) {}
      }
    }
    return total;
  }
}
