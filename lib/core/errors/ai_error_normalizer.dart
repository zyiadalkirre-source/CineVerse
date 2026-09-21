import 'dart:async';
import 'dart:io';

import 'package:google_generative_ai/google_generative_ai.dart';

class AiException implements Exception {
  const AiException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

class AiErrorNormalizer {
  const AiErrorNormalizer._();

  static AiException normalize(Object error) {
    final raw = error.toString();
    final lower = raw.toLowerCase();

    if (error is UnsupportedUserLocation ||
        lower.contains('unsupporteduserlocation') ||
        lower.contains('unsupported user location') ||
        lower.contains('unsupported_user_location') ||
        lower.contains('geo_blocked')) {
      return const AiException(
        'خدمة الذكاء الاصطناعي غير متاحة في منطقتك الجغرافية حالياً (تتطلب الاتصال بـ VPN أو Gateway).',
        code: 'GEO_BLOCKED',
      );
    }

    if (error is InvalidApiKey ||
        lower.contains('invalid api key') ||
        lower.contains('api key not valid') ||
        lower.contains('permission_denied') ||
        lower.contains('permission denied') ||
        lower.contains('status code: 403') ||
        RegExp(r'\b403\b').hasMatch(lower)) {
      return const AiException(
        'مفتاح خدمة الذكاء الاصطناعي غير صالح أو تم إلغاؤه.',
        code: 'API_KEY_INVALID',
      );
    }

    if (lower.contains('quota') ||
        lower.contains('resource_exhausted') ||
        lower.contains('rate limit') ||
        lower.contains('too many requests') ||
        RegExp(r'\b429\b').hasMatch(lower)) {
      return const AiException(
        'تم تجاوز حد الاستخدام المسموح لخدمة الذكاء الاصطناعي. يرجى المحاولة لاحقاً.',
        code: 'QUOTA_EXCEEDED',
      );
    }

    if (error is SocketException ||
        error is TimeoutException ||
        lower.contains('socketexception') ||
        lower.contains('timeout') ||
        lower.contains('timed out') ||
        lower.contains('deadline exceeded') ||
        lower.contains('clientexception') ||
        lower.contains('connection refused') ||
        lower.contains('network')) {
      return const AiException(
        'تعذر الاتصال بالخدمة. يرجى التحقق من اتصال الإنترنت.',
        code: 'NETWORK_ERROR',
      );
    }

    if (error is ServerException ||
        lower.contains('internal server error') ||
        lower.contains('service unavailable') ||
        RegExp(r'\b5\d{2}\b').hasMatch(lower)) {
      return const AiException(
        'خدمة الذكاء الاصطناعي تواجه مشكلة مؤقتة. يرجى المحاولة لاحقاً.',
        code: 'SERVER_ERROR',
      );
    }

    return const AiException(
      'حدث خطأ أثناء استخدام خدمة الذكاء الاصطناعي. يرجى المحاولة مرة أخرى.',
      code: 'AI_REQUEST_FAILED',
    );
  }
}
