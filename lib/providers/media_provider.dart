import 'package:flutter/foundation.dart';
import '../core/constants.dart';
import '../models/media_item.dart';
import '../models/user_stats.dart';
import '../services/database_service.dart';
import '../services/tmdb_service.dart';
import '../services/jikan_service.dart';

class MediaProvider extends ChangeNotifier {
  final TmdbService tmdb=TmdbService();
  final JikanService jikan=JikanService();
  final DatabaseService database=DatabaseService.instance;
  List<MediaItem> _library=[];
  bool loading=false;
  String? error;
  List<MediaItem> get library=>List.unmodifiable(_library);
  MediaProvider(){_load();}
  Future<void> _load() async {try{_library=await database.getLibrary();}catch(e){error=e.toString();}notifyListeners();}
  Future<void> upsert(MediaItem item) async {final i=_library.indexWhere((x)=>x.id==item.id&&x.mediaType==item.mediaType);if(i>=0)_library[i]=item;else _library.add(item);await database.saveMedia(item);notifyListeners();}
  Future<void> setStatus(MediaItem item,String status) async=>upsert(item.copyWith(watchStatus:status));
  Future<void> setRating(MediaItem item,double? rating) async=>upsert(item.copyWith(userRating:rating));
  Future<void> setNotes(MediaItem item,String notes) async=>upsert(item.copyWith(notes:notes));
  Future<void> clearLibrary() async{_library=[];await database.deleteLibrary();notifyListeners();}
  MediaItem? getById(int id,String type){for(final x in _library){if(x.id==id&&x.mediaType==type)return x;}return null;}
  Future<List<MediaItem>> search(String q,String lang) async{error=null;final r=<MediaItem>[];try{r.addAll(await tmdb.search(q,lang:lang));}catch(e){error=e.toString();}try{r.addAll(await jikan.searchAnime(q));}catch(_){}await database.addSearch(q);return r;}
  Future<List<MediaItem>> trending(String lang) async{loading=true;notifyListeners();try{return await tmdb.getTrending(lang:lang);}finally{loading=false;notifyListeners();}}
  Future<List<MediaItem>> topRated(String lang) async{try{return await tmdb.getTopRated(lang:lang);}catch(_){return [];}}
  Future<List<MediaItem>> topAnime()=>jikan.topAnime();
  Future<List<MediaItem>> recommendations(MediaItem item,String lang) async{if(item.mediaType=='anime')return jikan.topAnime();try{return await tmdb.getRecommendations(item.id,item.mediaType,lang:lang);}catch(_){return [];}}
  Future<MediaItem> details(MediaItem item,String lang) async{if(item.mediaType=='anime')return item;try{return await tmdb.getDetails(item.id,item.mediaType,lang:lang);}catch(_){return item;}}
  UserStats get stats{
    final watched=_library.where((x)=>x.watchStatus==AppConstants.statusWatched).toList();
    final watching=_library.where((x)=>x.watchStatus==AppConstants.statusWatching).length;
    final genres=<String,int>{},actors=<String,int>{};double hours=0,sum=0;int rated=0,m=0,t=0,a=0;
    for(final x in watched){if(x.mediaType=='movie')m++;else if(x.mediaType=='tv')t++;else a++;hours+=(x.runtime??0)/60;for(final g in x.genres)genres[g]=(genres[g]??0)+1;for(final c in x.cast.take(10))actors[c]=(actors[c]??0)+1;if(x.userRating!=null){sum+=x.userRating!;rated++;}}
    Map<String,int> top(Map<String,int> v){final e=v.entries.toList()..sort((a,b)=>b.value.compareTo(a.value));return Map.fromEntries(e.take(8));}
    return UserStats(totalWatched:watched.length,totalWatching:watching,totalWatchlist:_library.where((x)=>x.watchStatus==AppConstants.statusNotWatched).length,totalHours:hours,movies:m,tvShows:t,anime:a,averageRating:rated==0?0:sum/rated,topGenres:top(genres),topActors:top(actors));
  }
}