import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../l10n/translations.dart';
import '../models/media_item.dart';
import '../providers/media_provider.dart';
import '../providers/settings_provider.dart';
import 'search_screen.dart';
import 'detail_screen.dart';
import 'ai_hub_screen.dart';
import 'notes_screen.dart';
import 'stats_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget{const HomeScreen({super.key});@override State<HomeScreen> createState()=>_HomeScreenState();}
class _HomeScreenState extends State<HomeScreen>{int index=0;final pages=const [_Library(),_Discover(),AiHubScreen(),NotesScreen(),StatsScreen()];@override Widget build(BuildContext context){final t=AppLocalizations.of(context);return Scaffold(appBar:AppBar(title:Text(t.t('app_name')),actions:[IconButton(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const SearchScreen())),icon:const Icon(Icons.search)),IconButton(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const SettingsScreen())),icon:const Icon(Icons.settings))]),body:pages[index],bottomNavigationBar:NavigationBar(selectedIndex:index,onDestinationSelected:(v)=>setState(()=>index=v),destinations:[NavigationDestination(icon:const Icon(Icons.video_library_outlined),label:t.t('library')),NavigationDestination(icon:const Icon(Icons.explore_outlined),label:t.t('discover')),NavigationDestination(icon:const Icon(Icons.auto_awesome),label:t.t('ai')),NavigationDestination(icon:const Icon(Icons.note_outlined),label:t.t('notes')),NavigationDestination(icon:const Icon(Icons.bar_chart),label:t.t('stats'))]));}}
class _Library extends StatelessWidget{const _Library();@override Widget build(BuildContext context){final mp=context.watch<MediaProvider>();if(mp.library.isEmpty)return const Center(child:Text('أضف أفلاماً ومسلسلات إلى مكتبتك من البحث'));return GridView.builder(padding:const EdgeInsets.all(12),gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:3,crossAxisSpacing:10,mainAxisSpacing:10,childAspectRatio:.62),itemCount:mp.library.length,itemBuilder:(_,i)=>_Card(mp.library[i]));}}
class _Discover extends StatefulWidget{const _Discover();@override State<_Discover> createState()=>_DiscoverState();}
class _DiscoverState extends State<_Discover>{List<MediaItem> items=[];bool loading=true;@override void initState(){super.initState();_load();}Future<void> _load()async{final mp=context.read<MediaProvider>();try{items=await mp.trending(context.read<SettingsProvider>().locale.languageCode);}catch(_){ }if(mounted)setState(()=>loading=false);} @override Widget build(BuildContext context){if(loading)return const Center(child:CircularProgressIndicator());if(items.isEmpty)return Center(child:ElevatedButton(onPressed:(){setState(()=>loading=true);_load();},child:const Text('إعادة المحاولة')));return GridView.builder(padding:const EdgeInsets.all(12),gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:3,crossAxisSpacing:10,mainAxisSpacing:10,childAspectRatio:.62),itemCount:items.length,itemBuilder:(_,i)=>_Card(items[i]);}}
class _Card extends StatelessWidget{final MediaItem item;const _Card(this.item);@override Widget build(BuildContext context){return InkWell(onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>DetailScreen(item:item))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(child:ClipRRect(borderRadius:BorderRadius.circular(12),child:item.posterUrl==null?Container(color:Theme.of(context).colorScheme.surfaceContainerHighest,child:const Icon(Icons.movie)):Image.network(item.posterUrl!,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const Center(child:Icon(Icons.broken_image))))),const SizedBox(height:5),Text(item.title,maxLines:2,overflow:TextOverflow.ellipsis),Text(item.year,style:Theme.of(context).textTheme.bodySmall)]));}}
