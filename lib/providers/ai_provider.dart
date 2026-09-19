import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';
import '../models/media_item.dart';
import '../services/ai_models.dart';
import '../services/ai_service.dart';
import '../services/database_service.dart';
import '../services/tmdb_service.dart';
import '../services/jikan_service.dart';

class AiProvider extends ChangeNotifier {
  final AiService service = AiService();
  final DatabaseService database = DatabaseService.instance;
  final TmdbService tmdb = TmdbService();
  final JikanService jikan = JikanService();
  final List<ChatMessage> messages = [];
  bool loading = false;
  String streamingText = '';

  Future<void> loadChat() async {
    try { messages.addAll(await database.getChat()); } catch (_) {}
    notifyListeners();
  }

  Future<String> send(String q) async {
    if (q.trim().isEmpty) return '';
    loading = true;
    final user = ChatMessage(id: DateTime.now().microsecondsSinceEpoch.toString(), text: q, isUser: true, createdAt: DateTime.now());
    messages.add(user);
    await database.saveChat(user);
    notifyListeners();
    try {
      streamingText = '';
      final answer = await service.chat(q, messages);
      streamingText = answer;
      final bot = ChatMessage(id: DateTime.now().microsecondsSinceEpoch.toString(), text: answer, isUser: false, createdAt: DateTime.now());
      messages.add(bot);
      await database.saveChat(bot);
      return answer;
    } finally {
      loading = false;
      streamingText = '';
      notifyListeners();
    }
  }

  void clearChat() { messages.clear(); database.clearChat(); notifyListeners(); }
  Future<AiSummary> summarize(MediaItem i) => service.summarize(i);
  Future<WorthWatching> worthWatching(MediaItem i) => service.worthWatching(i);
  Future<String> explainEnding(MediaItem i) => service.explainEnding(i);
  Future<MoodResult> classifyMood(String q) => service.classifyMood(q);
  Future<PosterAnalysis> analyzePoster(Uint8List b) => service.analyzePoster(b);
  Future<TasteAnalysis> analyzeTaste(List<MediaItem> i) => service.analyzeTaste(i);

  Future<List<MediaItem>> smartSearch(String q) async {
    final titles = await service.suggestTitles(q);
    return _resolve(titles);
  }

  Future<List<MediaItem>> findSimilar(MediaItem i) async {
    final titles = await service.suggestTitles('works similar to ${i.title}; genres: ${i.genres.join(', ')}');
    return _resolve(titles);
  }

  Future<List<MediaItem>> personalized(List<MediaItem> items) async {
    if (items.isEmpty) return [];
    final seed = items.take(12).map((x) => x.title).join(', ');
    return smartSearch('recommend movies, TV and anime based on these titles: ${seed}');
  }

  Future<List<MediaItem>> _resolve(List<String> titles) async {
    final out = <MediaItem>[];
    for (final title in titles.take(6)) {
      try { out.addAll(await tmdb.search(title)); } catch (_) {}
      try { out.addAll(await jikan.searchAnime(title)); } catch (_) {}
    }
    final seen = <String>{};
    return out.where((x) => seen.add('${x.mediaType}:${x.id}')).take(20).toList();
  }
  Future<String> analyzeRatings(String title,{String imdb='',String rottenTomatoes='',String metacritic=''}) => service.analyzeRatings(title,imdb:imdb,rottenTomatoes:rottenTomatoes,metacritic:metacritic);
  Future<String> familyCheck(MediaItem i) => service.familyCheck(i);
  Future<String> compare(MediaItem a,MediaItem b) => service.compare(a,b);
  Future<String> comfortZone(List<MediaItem> i) => service.comfortZone(i);
  Future<String> themedList(String theme) => service.themedList(theme);
  Future<String> adaptationCompare(String source,String adaptation) => service.adaptationCompare(source,adaptation);
  Future<String> identifyFromDescription(String d) => service.identifyFromDescription(d);
  Future<String> autoTags(MediaItem i) => service.autoTags(i);
  Future<String> screenshotIdentify(String d) => service.screenshotIdentify(d);
  Future<String> generateQuiz(MediaItem i) => service.generateQuiz(i);
}
