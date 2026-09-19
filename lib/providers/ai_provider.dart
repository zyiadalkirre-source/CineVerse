import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';
import '../models/media_item.dart';
import '../services/ai_models.dart';
import '../services/ai_service.dart';
class AiProvider extends ChangeNotifier {
 final AiService service=AiService(); final List<ChatMessage> messages=[]; bool loading=false; String streamingText='';
 Future<String> send(String q) async{if(q.trim().isEmpty)return '';loading=true;messages.add(ChatMessage(id:DateTime.now().microsecondsSinceEpoch.toString(),text:q,isUser:true,createdAt:DateTime.now()));notifyListeners();try{final a=await service.chat(q,messages);messages.add(ChatMessage(id:DateTime.now().microsecondsSinceEpoch.toString(),text:a,isUser:false,createdAt:DateTime.now()));return a;}finally{loading=false;notifyListeners();}}
 void clearChat(){messages.clear();notifyListeners();}
 Future<AiSummary> summarize(MediaItem i)=>service.summarize(i);
 Future<WorthWatching> worthWatching(MediaItem i)=>service.worthWatching(i);
 Future<String> explainEnding(MediaItem i)=>service.explainEnding(i);
 Future<MoodResult> classifyMood(String q)=>service.classifyMood(q);
 Future<PosterAnalysis> analyzePoster(Uint8List b)=>service.analyzePoster(b);
 Future<TasteAnalysis> analyzeTaste(List<MediaItem> i)=>service.analyzeTaste(i);
 Future<List<MediaItem>> smartSearch(String q)=>Future.value([]);
 Future<List<MediaItem>> findSimilar(MediaItem i)=>Future.value([]);
 Future<List<MediaItem>> personalized(List<MediaItem> i)=>Future.value([]);
}