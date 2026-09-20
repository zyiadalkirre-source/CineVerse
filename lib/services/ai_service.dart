import 'dart:convert';
import 'dart:typed_data';

import 'package:google_generative_ai/google_generative_ai.dart';

import '../core/api_config.dart';
import '../core/constants.dart';
import '../models/chat_message.dart';
import '../models/media_item.dart';
import '../core/errors/ai_error_normalizer.dart';
import 'ai_models.dart';

class AiServiceException extends AiException {
  const AiServiceException(super.message, {super.code});
}

class AiService {
  GenerativeModel get model => GenerativeModel(
        model: AppConstants.geminiModel,
        apiKey: ApiConfig.geminiKey,
      );

  void _check() {
    if (ApiConfig.geminiKey.trim().isEmpty) {
      throw const AiServiceException(
        'خدمة الذكاء الاصطناعي غير مهيأة حالياً. يمكنك إضافة مفتاح Gemini من الإعدادات المتقدمة.',
        code: 'MISSING_API_KEY',
      );
    }
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    _check();
    try {
      return await action();
    } on AiException catch (error) {
      throw AiServiceException(error.message, code: error.code);
    } catch (error) {
      final normalized = AiErrorNormalizer.normalize(error);
      throw AiServiceException(normalized.message, code: normalized.code);
    }
  }

  Future<String> text(String prompt) {
    return _guard(() async {
      final response = await model.generateContent([Content.text(prompt)]);
      final value = response.text?.trim();
      if (value == null || value.isEmpty) {
        return 'لم يتم الحصول على إجابة من خدمة الذكاء الاصطناعي.';
      }
      return value;
    });
  }

  Future<List<String>> suggestTitles(String prompt) async {
    final raw = await text(
      'Return JSON array only. Give 6 movie, TV or anime titles matching: $prompt',
    );
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((value) => value.toString()).where((value) => value.trim().isNotEmpty).take(6).toList();
      }
    } catch (_) {}
    return raw
        .split('\n')
        .map((value) => value.replaceFirst(RegExp(r'^[-*\d. ]+'), '').trim())
        .where((value) => value.isNotEmpty)
        .take(6)
        .toList();
  }

  Future<String> chat(String q, List<ChatMessage> history) {
    final start = history.length > 20 ? history.length - 20 : 0;
    final recent = history
        .sublist(start)
        .map((message) => message.isUser ? 'User: ${message.text}' : 'Assistant: ${message.text}')
        .join('\n');
    return text(
      'You are CineVerse AI. Answer in the same language as the user. '
      'Use the recent conversation when relevant. Do not invent facts.\n'
      'Recent conversation:\n$recent\n'
      'Current user question: $q',
    );
  }

  Future<AiSummary> summarize(MediaItem item) async {
    final raw = await text(
      'Return JSON only with summary,strengths,audience,mood,similarTo. '
      'Analyze ${item.title}: ${item.overview}',
    );
    try {
      final decoded = jsonDecode(raw);
      return AiSummary(
        summary: '${decoded['summary'] ?? ''}',
        strengths: List<String>.from(decoded['strengths'] ?? const []),
        audience: '${decoded['audience'] ?? ''}',
        mood: '${decoded['mood'] ?? ''}',
        similarTo: List<String>.from(decoded['similarTo'] ?? const []),
      );
    } catch (_) {
      return AiSummary(summary: raw, strengths: const [], audience: '', mood: '', similarTo: const []);
    }
  }

  Future<WorthWatching> worthWatching(MediaItem item) async {
    final raw = await text(
      'Return JSON only with verdict,score,reason,forWhom,againstWhom,watchIf,skipIf. '
      'Analyze ${item.title}: ${item.overview}',
    );
    try {
      final decoded = jsonDecode(raw);
      return WorthWatching(
        verdict: '${decoded['verdict'] ?? ''}',
        score: (decoded['score'] as num?)?.toDouble() ?? 0,
        reason: '${decoded['reason'] ?? ''}',
        forWhom: '${decoded['forWhom'] ?? ''}',
        againstWhom: '${decoded['againstWhom'] ?? ''}',
        watchIf: '${decoded['watchIf'] ?? ''}',
        skipIf: '${decoded['skipIf'] ?? ''}',
      );
    } catch (_) {
      return WorthWatching.empty();
    }
  }

  Future<String> explainEnding(MediaItem item) =>
      text('Explain the ending of ${item.title}. Clearly label spoilers. ${item.overview}');

  Future<MoodResult> classifyMood(String query) async {
    final raw = await text(
      'Return JSON only with detectedMood,confidence,explanation,genres,avoidGenres,movies,anime. Mood: $query',
    );
    try {
      final decoded = jsonDecode(raw);
      return MoodResult(
        detectedMood: '${decoded['detectedMood'] ?? ''}',
        confidence: (decoded['confidence'] as num?)?.toDouble() ?? 0,
        explanation: '${decoded['explanation'] ?? ''}',
        genres: List<String>.from(decoded['genres'] ?? const []),
        avoidGenres: List<String>.from(decoded['avoidGenres'] ?? const []),
        movies: List<String>.from(decoded['movies'] ?? const []),
        anime: List<String>.from(decoded['anime'] ?? const []),
      );
    } catch (_) {
      return MoodResult.empty();
    }
  }

  Future<PosterAnalysis> analyzePoster(Uint8List bytes) {
    return _guard(() async {
      final visionModel = GenerativeModel(
        model: AppConstants.geminiVisionModel,
        apiKey: ApiConfig.geminiKey,
      );
      final response = await visionModel.generateContent([
        Content.multi([
          DataPart('image/jpeg', bytes),
          TextPart(
            'Return JSON only with type,genres,audience,mood,colors,colorMeaning,symbols,verdict. '
            'Analyze this poster.',
          ),
        ]),
      ]);
      final raw = response.text?.trim() ?? '';
      try {
        final decoded = jsonDecode(raw);
        return PosterAnalysis(
          type: '${decoded['type'] ?? ''}',
          genres: List<String>.from(decoded['genres'] ?? const []),
          audience: '${decoded['audience'] ?? ''}',
          mood: '${decoded['mood'] ?? ''}',
          colors: List<String>.from(decoded['colors'] ?? const []),
          colorMeaning: '${decoded['colorMeaning'] ?? ''}',
          symbols: List<String>.from(decoded['symbols'] ?? const []),
          verdict: '${decoded['verdict'] ?? ''}',
        );
      } catch (_) {
        return PosterAnalysis.empty();
      }
    });
  }

  Future<TasteAnalysis> analyzeTaste(List<MediaItem> items) async {
    final data = items.take(30).map((item) => '${item.title}|${item.genres.join(',')}|${item.userRating ?? ''}').join('\n');
    final raw = await text(
      'Return JSON only with archetype,personality,patterns,strengths,blindSpots,topGenres,avoidedGenres,recommendation. Library:\n$data',
    );
    try {
      final decoded = jsonDecode(raw);
      return TasteAnalysis(
        archetype: '${decoded['archetype'] ?? ''}',
        personality: '${decoded['personality'] ?? ''}',
        patterns: List<String>.from(decoded['patterns'] ?? const []),
        strengths: '${decoded['strengths'] ?? ''}',
        blindSpots: '${decoded['blindSpots'] ?? ''}',
        topGenres: List<String>.from(decoded['topGenres'] ?? const []),
        avoidedGenres: List<String>.from(decoded['avoidedGenres'] ?? const []),
        recommendation: '${decoded['recommendation'] ?? ''}',
      );
    } catch (_) {
      return TasteAnalysis.empty();
    }
  }

  Future<String> analyzeRatings(String title, {String imdb = '', String rottenTomatoes = '', String metacritic = ''}) =>
      text('Analyze ratings for "$title". IMDb: $imdb. Rotten Tomatoes: $rottenTomatoes. Metacritic: $metacritic. Do not invent missing ratings.');

  Future<String> familyCheck(MediaItem item) =>
      text('Provide a family-content suitability overview for "${item.title}". Use only supplied information. Overview: ${item.overview}. Genres: ${item.genres.join(', ')}.');

  Future<String> compare(MediaItem a, MediaItem b) =>
      text('Compare "${a.title}" and "${b.title}" factually across premise, genre, tone, audience, strengths and notable differences. First: ${a.overview}. Second: ${b.overview}.');

  Future<String> comfortZone(List<MediaItem> items) =>
      text('Analyze this viewing library and describe the user comfort zone: ${items.take(30).map((item) => '${item.title} | ${item.genres.join(', ')}').join('\n')}');

  Future<String> themedList(String theme) =>
      text('Create a themed movie, TV and anime list for: $theme. Return concise titles with one-line reasons.');

  Future<String> adaptationCompare(String sourceWork, String adaptation) =>
      text('Compare the source work "$sourceWork" with its adaptation "$adaptation". Separate known facts from uncertainty.');

  Future<String> identifyFromDescription(String description) =>
      text('Identify possible movie, TV or anime titles from this incomplete description: $description. Give up to 5 possibilities and explain uncertainty.');

  Future<String> autoTags(MediaItem item) =>
      text('Generate useful content tags for "${item.title}" from: ${item.overview}. Genres: ${item.genres.join(', ')}.');

  Future<String> screenshotIdentify(String description) =>
      text('Help identify a movie, TV show or anime from this screenshot description: $description. Give possible matches and uncertainty.');

  Future<String> generateQuiz(MediaItem item) =>
      text('Create a short spoiler-aware quiz about "${item.title}" using only supplied information. Overview: ${item.overview}.');
}
