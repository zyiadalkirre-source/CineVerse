import 'dart:convert';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../core/constants.dart';
import '../core/api_config.dart';
import '../models/media_item.dart';
import '../models/chat_message.dart';
import 'ai_models.dart';

class AiService {
 GenerativeModel get model=>GenerativeModel(model:AppConstants.geminiModel,apiKey:ApiConfig.geminiKey);
 void check(){if(ApiConfig.geminiKey.trim().isEmpty)throw StateError('GEMINI_API_KEY is not configured');}
 Future<String> text(String prompt) async{check();final r=await model.generateContent([Content.text(prompt)]);return r.text?.trim()??'لم يتم الحصول على إجابة.';}
 Future<List<String>> suggestTitles(String prompt) async { final raw=await text('Return JSON array only. Give 6 movie, TV or anime titles matching: $prompt'); try { return List<String>.from(jsonDecode(raw)); } catch (_) { return raw.split('\n').map((x)=>x.replaceFirst(RegExp(r'^[-*\\d. ]+'),'').trim()).where((x)=>x.isNotEmpty).take(6).toList(); } }
 Future<String> chat(String q,List<ChatMessage> history){final start=history.length>20?history.length-20:0;final recent=history.sublist(start).map((m)=>m.isUser?'User: ${m.text}':'Assistant: ${m.text}').join('\n');return text('You are CineVerse AI. Answer in the same language as the user. Use the recent conversation when relevant. Do not invent facts.\nRecent conversation:\n$recent\nCurrent user question: $q');}
 Future<AiSummary> summarize(MediaItem i) async{final raw=await text('Return JSON only with summary,strengths,audience,mood,similarTo. Analyze '+i.title+': '+i.overview);try{final j=jsonDecode(raw);return AiSummary(summary:'${j['summary']??''}',strengths:List<String>.from(j['strengths']??[]),audience:'${j['audience']??''}',mood:'${j['mood']??''}',similarTo:List<String>.from(j['similarTo']??[]));}catch(_){return AiSummary(summary:raw,strengths:const [],audience:'',mood:'',similarTo:const []);}}
 Future<WorthWatching> worthWatching(MediaItem i) async{final raw=await text('Return JSON only with verdict,score,reason,forWhom,againstWhom,watchIf,skipIf. Analyze '+i.title+': '+i.overview);try{final j=jsonDecode(raw);return WorthWatching(verdict:'${j['verdict']??''}',score:(j['score'] as num?)?.toDouble()??0,reason:'${j['reason']??''}',forWhom:'${j['forWhom']??''}',againstWhom:'${j['againstWhom']??''}',watchIf:'${j['watchIf']??''}',skipIf:'${j['skipIf']??''}');}catch(_){return WorthWatching.empty();}}
 Future<String> explainEnding(MediaItem i)=>text('Explain the ending of '+i.title+'. Clearly label spoilers. '+i.overview);
 Future<MoodResult> classifyMood(String q) async{final raw=await text('Return JSON only with detectedMood,confidence,explanation,genres,avoidGenres,movies,anime. Mood: '+q);try{final j=jsonDecode(raw);return MoodResult(detectedMood:'${j['detectedMood']??''}',confidence:(j['confidence'] as num?)?.toDouble()??0,explanation:'${j['explanation']??''}',genres:List<String>.from(j['genres']??[]),avoidGenres:List<String>.from(j['avoidGenres']??[]),movies:List<String>.from(j['movies']??[]),anime:List<String>.from(j['anime']??[]));}catch(_){return MoodResult.empty();}}
 Future<PosterAnalysis> analyzePoster(Uint8List bytes) async{check(); final m=GenerativeModel(model:AppConstants.geminiVisionModel,apiKey:ApiConfig.geminiKey);final r=await m.generateContent([Content.multi([DataPart('image/jpeg',bytes),TextPart('Return JSON only with type,genres,audience,mood,colors,colorMeaning,symbols,verdict. Analyze this poster.')])]);final raw=r.text??'';try{final j=jsonDecode(raw);return PosterAnalysis(type:'${j['type']??''}',genres:List<String>.from(j['genres']??[]),audience:'${j['audience']??''}',mood:'${j['mood']??''}',colors:List<String>.from(j['colors']??[]),colorMeaning:'${j['colorMeaning']??''}',symbols:List<String>.from(j['symbols']??[]),verdict:'${j['verdict']??''}');}catch(_){return PosterAnalysis.empty();}}
 Future<TasteAnalysis> analyzeTaste(List<MediaItem> items) async{final data=items.take(30).map((x)=>x.title+'|'+x.genres.join(',')+'|'+(x.userRating?.toString()??'')).join('\n');final raw=await text('Return JSON only with archetype,personality,patterns,strengths,blindSpots,topGenres,avoidedGenres,recommendation. Library:\n'+data);try{final j=jsonDecode(raw);return TasteAnalysis(archetype:'${j['archetype']??''}',personality:'${j['personality']??''}',patterns:List<String>.from(j['patterns']??[]),strengths:'${j['strengths']??''}',blindSpots:'${j['blindSpots']??''}',topGenres:List<String>.from(j['topGenres']??[]),avoidedGenres:List<String>.from(j['avoidedGenres']??[]),recommendation:'${j['recommendation']??''}');}catch(_){return TasteAnalysis.empty();}}
  Future<String> analyzeRatings(
    String title, {
    String imdb = '',
    String rottenTomatoes = '',
    String metacritic = '',
  }) => text(
    'Analyze the supplied ratings for "$title". '
    'IMDb: $imdb. Rotten Tomatoes: $rottenTomatoes. Metacritic: $metacritic. '
    'Do not invent missing ratings. Explain differences and limitations.',
  );

  Future<String> familyCheck(MediaItem item) => text(
    'Provide a family-content suitability overview for "${item.title}". '
    'Use only the information supplied here and clearly say when information is unknown. '
    'Overview: ${item.overview}. Genres: ${item.genres.join(', ')}.',
  );

  Future<String> compare(MediaItem a, MediaItem b) => text(
    'Compare "${a.title}" and "${b.title}" factually across premise, genre, tone, '
    'audience, strengths and notable differences. Do not invent missing facts. '
    'First: ${a.overview}. Second: ${b.overview}.',
  );

  Future<String> comfortZone(List<MediaItem> items) => text(
    'Analyze this viewing library and describe the user comfort zone: '
    '${items.take(30).map((i) => '${i.title} | ${i.genres.join(', ')}').join('\\n')}',
  );

  Future<String> themedList(String theme) => text(
    'Create a themed movie, TV and anime list for: $theme. '
    'Return concise titles with one-line reasons. Clearly mark uncertain items.',
  );

  Future<String> adaptationCompare(String sourceWork, String adaptation) => text(
    'Compare the source work "$sourceWork" with its adaptation "$adaptation". '
    'Separate known facts from uncertainty and avoid inventing plot details.',
  );

  Future<String> identifyFromDescription(String description) => text(
    'Identify possible movie, TV or anime titles from this incomplete description: '
    '$description. Give up to 5 possibilities and explain uncertainty.',
  );

  Future<String> autoTags(MediaItem item) => text(
    'Generate useful content tags for "${item.title}" from this information: '
    '${item.overview}. Genres: ${item.genres.join(', ')}. '
    'Return concise comma-separated tags and do not invent specific facts.',
  );

  Future<String> screenshotIdentify(String description) => text(
    'Help identify a movie, TV show or anime from this screenshot description: '
    '$description. Give possible matches and uncertainty.',
  );

  Future<String> generateQuiz(MediaItem item) => text(
    'Create a short spoiler-aware quiz about "${item.title}" using only supplied information. '
    'If the supplied information is insufficient, say so instead of inventing facts. '
    'Overview: ${item.overview}.',
  );}
