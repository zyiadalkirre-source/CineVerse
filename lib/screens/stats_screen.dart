import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/media_provider.dart';

class StatsScreen extends StatelessWidget{
 const StatsScreen({super.key});
 @override Widget build(BuildContext context){
  final s=context.watch<MediaProvider>().stats;
  final sections=s.totalWatched==0?[PieChartSectionData(value:1,title:'0',radius:55)]:[
   PieChartSectionData(value:s.movies.toDouble(),title:'أفلام',radius:55),
   PieChartSectionData(value:s.tvShows.toDouble(),title:'مسلسلات',radius:55),
   PieChartSectionData(value:s.anime.toDouble(),title:'أنمي',radius:55),
  ].where((x)=>x.value>0).toList();
  final genres=s.topGenres.entries.toList();
  return ListView(padding:const EdgeInsets.all(16),children:[
   Text('الإحصائيات',style:Theme.of(context).textTheme.headlineSmall),const SizedBox(height:12),
   Wrap(spacing:8,runSpacing:8,children:[
    _card('تمت المشاهدة',s.totalWatched.toString()),_card('قيد المشاهدة',s.totalWatching.toString()),_card('قائمة الانتظار',s.totalWatchlist.toString()),_card('الساعات',s.totalHours.toStringAsFixed(1)),_card('متوسط تقييمي',s.averageRating.toStringAsFixed(1)),
   ]),
   const SizedBox(height:20),Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(children:[const Text('توزيع المكتبة'),SizedBox(height:220,child:PieChart(PieChartData(sections:sections,centerSpaceRadius:45)))]))),
   const SizedBox(height:20),
   if(genres.isNotEmpty) Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(children:[
    const Align(alignment:AlignmentDirectional.centerStart,child:Text('الأنواع الأكثر مشاهدة')),
    SizedBox(height:220,child:BarChart(BarChartData(borderData:FlBorderData(show:false),barGroups:[for(int i=0;i<genres.length;i++)BarChartGroupData(x:i,barRods:[BarChartRodData(toY:genres[i].value.toDouble(),width:18)])],titlesData:FlTitlesData(bottomTitles:AxisTitles(sideTitles:SideTitles(showTitles:true,getTitlesWidget:(v,m)=>Text(v.toInt()<genres.length?genres[v.toInt()].key:'',style:const TextStyle(fontSize:9))))))),
   ]))),
   const SizedBox(height:12),Text('الممثلون الأكثر ظهوراً',style:Theme.of(context).textTheme.titleLarge),
   ...s.topActors.entries.map((e)=>ListTile(title:Text(e.key),trailing:Text(e.value.toString()))),
  ]);
 }
 Widget _card(String a,String b)=>SizedBox(width:150,child:Card(child:ListTile(title:Text(a,style:const TextStyle(fontSize:12)),subtitle:Text(b,style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold)))));
}