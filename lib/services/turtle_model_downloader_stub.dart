class TurtleModelDownloader {
  const TurtleModelDownloader._();

  static const modelFilename =
      'qwen3_0.6b_nothink_q4_block32_ekv1280.litertlm';

  static Future<String> download({
    void Function(double progress)? onProgress,
  }) {
    throw UnsupportedError(
      'تنزيل نموذج Turtle غير متاح على هذه المنصة. استخدم Android أو iOS.',
    );
  }
}