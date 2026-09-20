import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class TurtleModelDownloader {
  const TurtleModelDownloader._();

  static const modelUrl =
      'https://huggingface.co/litert-community/Qwen3-0.6B-int4/resolve/main/'
      'qwen3_0.6b_nothink_q4_block32_ekv1280.litertlm?download=true';
  static const modelFilename =
      'qwen3_0.6b_nothink_q4_block32_ekv1280.litertlm';

  static Future<String> download({
    void Function(double progress)? onProgress,
  }) async {
    final directory = await getApplicationSupportDirectory();
    final modelFile = File(p.join(directory.path, modelFilename));
    final tempFile = File('${modelFile.path}.part');

    if (await modelFile.exists() &&
        await modelFile.length() >= 300 * 1024 * 1024) {
      onProgress?.call(1);
      return modelFile.path;
    }

    if (await tempFile.exists()) {
      await tempFile.delete();
    }

    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(modelUrl));
      final response = await client.send(request).timeout(
        const Duration(minutes: 20),
      );

      if (response.statusCode != 200) {
        throw HttpException(
          'تعذر تنزيل نموذج Turtle (HTTP ${response.statusCode}).',
        );
      }

      final total = response.contentLength;
      var received = 0;
      final sink = tempFile.openWrite();

      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (total != null && total > 0) {
            onProgress?.call(received / total);
          }
        }
      } finally {
        await sink.flush();
        await sink.close();
      }

      if (total != null && received != total) {
        throw StateError(
          'اكتمل تنزيل غير صحيح لنموذج Turtle. حاول التنزيل مرة أخرى.',
        );
      }

      if (await modelFile.exists()) {
        await modelFile.delete();
      }
      await tempFile.rename(modelFile.path);

      onProgress?.call(1);
      return modelFile.path;
    } finally {
      client.close();
    }
  }
}