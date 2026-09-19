import 'package:hive_flutter/hive_flutter.dart';

class CacheService {
  static const String _mediaBox = 'media_cache';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_mediaBox);
  }

  static Future<void> saveData(String key, dynamic value) async {
    final box = Hive.box(_mediaBox);
    await box.put(key, value);
  }

  static dynamic getData(String key) {
    final box = Hive.box(_mediaBox);
    return box.get(key);
  }
}
