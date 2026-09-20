import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}
class _HomeScreenState extends State<HomeScreen> {
  int index = 0;
  final pages = const [_Library(), _Discover(), AiHubScreen(), NotesScreen(), StatsScreen()];
  @override Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.t('app_name')),
        actions: [
          IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())), icon: const Icon(Icons.search)),
          IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())), icon: const Icon(Icons.settings)),
        ],
      ),
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index, onDestinationSelected: (v) => setState(() => index = v),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.video_library_outlined), label: t.t('library')),
          NavigationDestination(icon: const Icon(Icons.explore_outlined), label: t.t('discover')),
          NavigationDestination(icon: const Icon(Icons.auto_awesome), label: t.t('ai')),
          NavigationDestination(icon: const Icon(Icons.note_outlined), label: t.t('notes')),
          NavigationDestination(icon: const Icon(Icons.bar_chart), label: t.t('stats')),
        ],
      ),
    );
  }
}
class _Library extends StatefulWidget {
  const _Library();
  @override State<_Library> createState()=>_LibraryState();
}
class _LibraryState extends State<_Library> {
  String filter='all';
  bool _showWelcomeBanner = true;
  List<MediaItem> _filtered(List<MediaItem> items){
    final r=items.where((x)=>filter=='movie'?x.mediaType=='movie':filter=='tv'?x.mediaType=='tv':filter=='favorite'?x.isFavorite:true).toList();
    r.sort((a,b){if(a.lastWatchedSeconds>0&&b.lastWatchedSeconds==0)return -1;if(a.lastWatchedSeconds==0&&b.lastWatchedSeconds>0)return 1;return a.title.toLowerCase().compareTo(b.title.toLowerCase());});return r;
  }
  Widget _chip(String label,String value)=>Padding(padding:const EdgeInsets.only(right:7),child:ChoiceChip(label:Text(label),selected:filter==value,onSelected:(_)=>setState(()=>filter=value)));
  @override Widget build(BuildContext context) {
    final provider = context.watch<MediaProvider>();
    final theme = Theme.of(context);
    return CustomScrollView(slivers: [
      if (_showWelcomeBanner)
        SliverToBoxAdapter(child: Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 18), padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [theme.colorScheme.primary, theme.colorScheme.secondary]),
            boxShadow: [BoxShadow(color: theme.colorScheme.primary.withOpacity(.22), blurRadius: 24, offset: const Offset(0, 10))],
          ),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('عالمك السينمائي', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: Colors.white)),
              const SizedBox(height: 8),
              Text(provider.library.isEmpty ? 'اكتشف، احفظ، وتابع كل ما تحب.' : provider.library.length.toString() + ' عمل محفوظ في مكتبتك', style: const TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 18),
              FilledButton.tonalIcon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())), icon: const Icon(Icons.explore), label: const Text('اكتشف الآن')),
            ])),
            const SizedBox(width: 10),
            Stack(children: [
              const Icon(Icons.movie_filter_rounded, size: 82, color: Colors.white24),
              Positioned(
                top: 0, left: 0,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => setState(() => _showWelcomeBanner = false),
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.close, color: Colors.white, size: 22),
                    ),
                  ),
                ),
              ),
            ]),
          ]),
        )),
      if (provider.library.isNotEmpty) ...[
        SliverToBoxAdapter(child: Padding(padding:const EdgeInsets.symmetric(horizontal:14,vertical:4),child:SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[_chip('الكل','all'),_chip('أفلام','movie'),_chip('مسلسلات','tv'),_chip('المفضلة','favorite')])))),
        if(filter=='all'&&provider.library.any((x)=>x.lastWatchedSeconds>0))
          SliverToBoxAdapter(child:_HorizontalSection(title:'تابع المشاهدة',icon:Icons.play_circle_fill,items:provider.library.where((x)=>x.lastWatchedSeconds>0).toList())),
        if(filter=='all'&&provider.library.any((x)=>x.isFavorite))
          SliverToBoxAdapter(child:_HorizontalSection(title:'المفضلة ❤️',icon:Icons.favorite,items:provider.library.where((x)=>x.isFavorite).toList())),
        if(filter=='all'&&provider.library.any((x)=>x.watchStatus=='not_watched'))
          SliverToBoxAdapter(child:_HorizontalSection(title:'قائمتي',icon:Icons.bookmark,items:provider.library.where((x)=>x.watchStatus=='not_watched').toList())),
        SliverToBoxAdapter(child:_SectionHeader(title:filter=='all'?'كل مكتبتك':'نتائج الفلترة',icon:Icons.video_library)),
        SliverPadding(padding:const EdgeInsets.fromLTRB(16,0,16,20),sliver:SliverGrid(
          gridDelegate:const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent:170,mainAxisExtent:265,crossAxisSpacing:12,mainAxisSpacing:14),
          delegate:SliverChildBuilderDelegate((_,i)=>_MediaCard(_filtered(provider.library)[i]),childCount:_filtered(provider.library).length),
        )),
      ] else const SliverFillRemaining(hasScrollBody: false, child: Center(child: Padding(padding: EdgeInsets.all(32), child: Text('مكتبتك فاضية حالياً\nابحث عن فيلم أو مسلسل وأضفه هون.', textAlign: TextAlign.center, style: TextStyle(fontSize: 17))))),
    ]);
  }
}

class _HorizontalSection extends StatelessWidget {
  final String title; final IconData icon; final List<MediaItem> items;
  const _HorizontalSection({required this.title,required this.icon,required this.items});
  @override Widget build(BuildContext context)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    _SectionHeader(title:title,icon:icon),
    SizedBox(height:220,child:ListView.separated(padding:const EdgeInsets.symmetric(horizontal:16),scrollDirection:Axis.horizontal,itemCount:items.length,separatorBuilder:(_,__)=>const SizedBox(width:12),itemBuilder:(_,i)=>SizedBox(width:125,child:_MediaCard(items[i])))),
    const SizedBox(height:8),
  ]);
}
class _SectionHeader extends StatelessWidget {
  final String title; final IconData icon;
  const _SectionHeader({required this.title, required this.icon});
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(18, 4, 18, 12), child: Row(children: [Icon(icon, size: 20), const SizedBox(width: 8), Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800))]));
}
class _Discover extends StatefulWidget {
  const _Discover();
  @override State<_Discover> createState() => _DiscoverState();
}
class _DiscoverState extends State<_Discover> {
  List<MediaItem> items = []; bool loading = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final provider = context.read<MediaProvider>();
    try { items = await provider.trending(context.read<SettingsProvider>().locale.languageCode); } catch (_) { items = []; }
    if (mounted) setState(() => loading = false);
  }
  @override Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (items.isEmpty) return Center(child: ElevatedButton(onPressed: () { setState(() => loading = true); _load(); }, child: const Text('إعادة المحاولة')));
    return GridView.builder(padding: const EdgeInsets.all(12), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: .62), itemCount: items.length, itemBuilder: (_, i) => _MediaCard(items[i]));
  }
}
class _MediaCard extends StatelessWidget {
  final MediaItem item;
  const _MediaCard(this.item);
  @override Widget build(BuildContext context) => InkWell(
    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailScreen(item: item))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: Stack(children:[
        ClipRRect(borderRadius:BorderRadius.circular(12),child:SizedBox(width:double.infinity,height:double.infinity,child:item.posterUrl==null?Container(color:Theme.of(context).colorScheme.surfaceContainerHighest,child:const Icon(Icons.movie)):Image.network(item.posterUrl!,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const Center(child:Icon(Icons.broken_image))))),
        if(item.isFavorite)const Positioned(top:7,right:7,child:CircleAvatar(radius:15,backgroundColor:Colors.black54,child:Icon(Icons.favorite,size:16,color:Colors.white))),
        if(item.lastWatchedSeconds>0)const Positioned(left:7,bottom:7,child:Chip(label:Text('متابعة',style:TextStyle(fontSize:10)))),
      ])),
      const SizedBox(height: 5),
      Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      Text(item.year, style: Theme.of(context).textTheme.bodySmall),
    ]),
  );
}
