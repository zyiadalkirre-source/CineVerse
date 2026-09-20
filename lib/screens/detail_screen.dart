import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'watch_screen.dart';
import '../core/constants.dart';
import '../models/media_item.dart';
import '../providers/media_provider.dart';
import '../providers/ai_provider.dart';

class DetailScreen extends StatefulWidget {
  final MediaItem item;
  const DetailScreen({super.key, required this.item});
  @override State<DetailScreen> createState() => _DetailScreenState();
}
class _DetailScreenState extends State<DetailScreen> {
  late MediaItem item;
  bool loading=false, episodesLoading=false;
  List<Map<String,dynamic>> episodes=[];
  List<MediaItem> recommendations=[];
  int season=1;
  int? selectedEpisodeNumber;
  @override void initState(){super.initState();item=widget.item;_load();}
  Future<void> _load() async {
    final p=context.read<MediaProvider>();
    final x=await p.details(item,'ar');
    if(!mounted)return;
    setState(()=>item=x);
    try { final r=await p.recommendations(x,'ar'); if(mounted)setState(()=>recommendations=r.take(10).toList()); } catch(_){}
    if(x.mediaType=='tv' && (x.seasons??0)>0) _loadEpisodes(1);
  }
  Future<void> _loadEpisodes(int s) async {
    setState(()=>episodesLoading=true);
    try {
      final e=await context.read<MediaProvider>().tmdb.getTvEpisodes(item.id,s);
      if(mounted)setState(() {
        episodes=e;
        if (item.lastWatchedSeason == s) selectedEpisodeNumber=item.lastWatchedEpisode;
        else selectedEpisodeNumber=null;
      });
    }
    catch(_){if(mounted)setState(()=>episodes=[]);}
    finally{if(mounted)setState(()=>episodesLoading=false);}
  }
  Future<void> _status(String s) async {
    final provider = context.read<MediaProvider>();
    final inLibrary = provider.getById(item.id, item.mediaType) != null;
    if (s == AppConstants.statusNotWatched && inLibrary) {
      await provider.remove(item);
      if (mounted) setState(() => item = item.copyWith(watchStatus: AppConstants.statusNotWatched));
      return;
    }
    await provider.setStatus(item, s);
    if (mounted) setState(() => item = item.copyWith(watchStatus: s));
  }
  Future<void> _note()async{final c=TextEditingController(text:item.notes);final ok=await showDialog<bool>(context:context,builder:(_)=>AlertDialog(title:const Text('ملاحظتي'),content:TextField(controller:c,maxLines:5),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('إلغاء')),ElevatedButton(onPressed:()=>Navigator.pop(context,true),child:const Text('حفظ'))]));if(ok==true){await context.read<MediaProvider>().setNotes(item,c.text);if(mounted)setState(()=>item=item.copyWith(notes:c.text));}c.dispose();}
  Future<void> _ai()async{setState(()=>loading=true);try{final x=await context.read<AiProvider>().summarize(item);if(mounted)showDialog(context:context,builder:(_)=>AlertDialog(title:const Text('ملخص AI'),content:SingleChildScrollView(child:Text(x.summary)),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('إغلاق'))]));}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}finally{if(mounted)setState(()=>loading=false);}}
  @override Widget build(BuildContext context){
    final tv=item.mediaType=='tv';
    return Scaffold(body:CustomScrollView(slivers:[
      SliverAppBar(expandedHeight:300,pinned:true,flexibleSpace:FlexibleSpaceBar(title:Text(item.title,maxLines:1,overflow:TextOverflow.ellipsis),background:item.backdropUrl==null?Container(color:Theme.of(context).colorScheme.surfaceContainerHighest):Image.network(item.backdropUrl!,fit:BoxFit.cover,errorBuilder:(_,__,___)=>Container(color:Theme.of(context).colorScheme.surfaceContainerHighest)))),
      SliverToBoxAdapter(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
          if(item.posterUrl!=null)ClipRRect(borderRadius:BorderRadius.circular(14),child:Image.network(item.posterUrl!,width:105,height:155,fit:BoxFit.cover)),
          const SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(item.title,style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.bold)),
            if(item.originalTitle!=null&&item.originalTitle!=item.title)Text(item.originalTitle!,style:Theme.of(context).textTheme.bodySmall),
            const SizedBox(height:8),
            Text('⭐ '+item.voteAverage.toStringAsFixed(1)+'  •  '+item.year),
            if(tv)Text('📺 '+(item.seasons??0).toString()+' مواسم • '+(item.episodes??0).toString()+' حلقة'),
            if(item.runtime!=null)Text('⏱ '+item.runtime.toString()+' دقيقة'),
          ])),
        ]),
        const SizedBox(height:16),
        Row(children:[
          _statusButton('تمت',AppConstants.statusWatched),
          _statusButton('أشاهد',AppConstants.statusWatching),
          _statusButton('قائمة',AppConstants.statusNotWatched),
        ]),
        const SizedBox(height:8),
        SizedBox(width:double.infinity,child:OutlinedButton.icon(
          onPressed:() async { await context.read<MediaProvider>().toggleFavorite(item); if(mounted)setState(()=>item=item.copyWith(isFavorite:!item.isFavorite)); },
          icon:Icon(item.isFavorite?Icons.favorite:Icons.favorite_border),
          label:Text(item.isFavorite?'إزالة من المفضلة':'إضافة للمفضلة'),
        )),
        const SizedBox(height:18),
        Text('القصة',style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.bold)),
        const SizedBox(height:6),Text(item.overview.isEmpty?'لا يوجد وصف متاح':item.overview),
        const SizedBox(height:14),
        if(item.genres.isNotEmpty)Wrap(spacing:7,children:item.genres.map((g)=>Chip(label:Text(g))).toList()),
        const SizedBox(height:10),
        Text('التقييم العالمي: '+item.voteAverage.toStringAsFixed(1)+' / 10'),
        Text('عدد التقييمات: '+item.voteCount.toString()),
        if(item.cast.isNotEmpty)Padding(padding:const EdgeInsets.only(top:10),child:Text('طاقم العمل: '+item.cast.take(10).join(' • '))),
        if(item.director!=null)Text('المخرج: '+item.director!),
        if(tv&&(item.seasons??0)>0)...[
          const SizedBox(height:22),Text('الحلقات',style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.bold)),
          DropdownButton<int>(value:season,items:List.generate(item.seasons!, (i)=>DropdownMenuItem(value:i+1,child:Text('الموسم '+(i+1).toString()))),onChanged:(v){if(v!=null){setState(()=>season=v);_loadEpisodes(v);}}),
          if(episodesLoading)const LinearProgressIndicator(),
          ...episodes.map((e){
            final episodeNumber=(e['episode_number'] as num?)?.toInt()??0;
            final selected=selectedEpisodeNumber==episodeNumber;
            return Card(
              clipBehavior:Clip.antiAlias,
              color:selected ? Theme.of(context).colorScheme.surfaceContainerHighest : null,
              child:Stack(
                children:[
                  ListTile(
                    onTap:()=>_openEpisode(e),
                    leading:CircleAvatar(child:Text(episodeNumber.toString())),
                    title:Text((e['name']??'حلقة').toString(),style:selected?const TextStyle(fontWeight:FontWeight.bold):null),
                    subtitle:Text('التقييم: '+_episodeRating(e)+' • '+(e['air_date']??'—').toString()),
                    trailing:Icon(selected?Icons.star:Icons.play_circle_fill,color:selected?Theme.of(context).colorScheme.primary:null),
                  ),
                  if(selected) Positioned.fill(child:IgnorePointer(child:ColoredBox(color:Colors.black.withValues(alpha:0.12)))),
                  if(selected) Positioned(top:4,left:4,child:Icon(Icons.star,color:Colors.white,shadows:const [Shadow(blurRadius:3)])),
                ],
              ),
            );
          }),
        ],
        const SizedBox(height:16),
        Wrap(spacing:8,children:[ElevatedButton.icon(onPressed:_note,icon:const Icon(Icons.note_add),label:const Text('ملاحظة')),ElevatedButton.icon(onPressed:loading?null:_ai,icon:const Icon(Icons.auto_awesome),label:const Text('تحليل AI')),if(item.trailerKey!=null)IconButton(onPressed:()=>launchUrl(Uri.parse('https://www.youtube.com/watch?v='+item.trailerKey!)),icon:const Icon(Icons.play_circle))]),
        if(recommendations.isNotEmpty)...[const SizedBox(height:20),Text('اقتراحات مشابهة',style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.bold)),SizedBox(height:180,child:ListView.separated(scrollDirection:Axis.horizontal,itemCount:recommendations.length,separatorBuilder:(_,__)=>const SizedBox(width:10),itemBuilder:(_,i)=>SizedBox(width:105,child:InkWell(
  onTap:()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>DetailScreen(item:recommendations[i]))),
  borderRadius:BorderRadius.circular(10),
  child:Column(children:[
    if(recommendations[i].posterUrl!=null)
      ClipRRect(borderRadius:BorderRadius.circular(10),child:Image.network(recommendations[i].posterUrl!,height:140,width:100,fit:BoxFit.cover,errorBuilder:(_,__,___)=>Container(width:100,height:140,color:Theme.of(context).colorScheme.surfaceContainerHighest,child:const Icon(Icons.broken_image_outlined)))),
    const SizedBox(height:4),
    Text(recommendations[i].title,maxLines:2,overflow:TextOverflow.ellipsis,textAlign:TextAlign.center),
  ]),
))))],
      ]))),
    ]));
  }
  void _openEpisode(Map<String,dynamic> episode){
    final number=(episode['episode_number'] as num?)?.toInt()??0;
    setState(()=>selectedEpisodeNumber=number);
    final url=_episodeWatchUrl(episode);Navigator.of(context).push(MaterialPageRoute(builder:(_)=>WatchScreen(item:item, title:item.title,episodeName:(episode['name']??'حلقة').toString(),season:season,episode:(episode['episode_number'] as num?)?.toInt()??0,videoUrl:url)));}
  String? _episodeWatchUrl(Map<String,dynamic> episode){for(final key in const ['watch_url','video_url','stream_url','playback_url']){final value=episode[key]?.toString().trim();if(value!=null&&value.isNotEmpty)return value;}return null;}
  String _episodeRating(Map<String,dynamic> e){final value=e['vote_average'];return value is num?value.toStringAsFixed(1):'—';}
  Widget _statusButton(String l,String s){
    final selected = item.watchStatus == s && (s != AppConstants.statusNotWatched || context.read<MediaProvider>().getById(item.id,item.mediaType) != null);
    final isList = s == AppConstants.statusNotWatched;
    return Expanded(child:Padding(padding:const EdgeInsets.only(right:4),child:OutlinedButton.icon(
      onPressed:()=>_status(s),
      icon:Icon(selected ? Icons.check_circle : (isList && context.read<MediaProvider>().getById(item.id,item.mediaType)==null ? Icons.add : Icons.remove_done),size:18),
      label:Text(selected ? (isList ? 'بالقائمة' : l) : (isList ? 'إضافة' : l)),
      style:OutlinedButton.styleFrom(backgroundColor:selected ? Theme.of(context).colorScheme.primaryContainer : null,foregroundColor:selected ? Theme.of(context).colorScheme.onPrimaryContainer : null),
    )));
  }
}