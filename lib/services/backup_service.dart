import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../models/media_item.dart';

class BackupService {
  static const int schemaVersion = 1;

  static Future<void> exportLibrary(List<MediaItem> library) async {
    final payload = {
      'app': 'CineVerse',
      'schema_version': schemaVersion,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'items': library.map((item) => item.toJson()).toList(),
    };

    final bytes = Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(payload)),
    );

    await Share.shareXFiles(
      [
        XFile.fromData(
          bytes,
          mimeType: 'application/json',
          name: 'cineverse_backup.json',
        ),
      ],
      subject: 'CineVerse backup',
      text: 'نسخة احتياطية من مكتبة CineVerse.',
    );
  }

  static Future<List<MediaItem>?> importLibrary() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    final data = file.bytes;
    if (data == null) {
      throw const FormatException('تعذر قراءة ملف النسخة الاحتياطية.');
    }

    final decoded = jsonDecode(utf8.decode(data));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('صيغة النسخة الاحتياطية غير صحيحة.');
    }

    if (decoded['app'] != 'CineVerse') {
      throw const FormatException('هذا الملف ليس نسخة احتياطية من CineVerse.');
    }

    final version = (decoded['schema_version'] as num?)?.toInt();
    if (version != schemaVersion) {
      throw FormatException('إصدار النسخة الاحتياطية غير مدعوم: $version');
    }

    final rawItems = decoded['items'];
    if (rawItems is! List) {
      throw const FormatException('لا توجد مكتبة صالحة داخل الملف.');
    }

    return rawItems
        .whereType<Map>()
        .map((item) => MediaItem.fromJson(Map<String, dynamic>.from(item)))
        .where((item) => item.id != 0 && item.title.trim().isNotEmpty)
        .toList();
  }
}
