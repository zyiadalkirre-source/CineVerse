import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/media_provider.dart';
import 'detail_screen.dart';
class NotesScreen extends StatelessWidget{const NotesScreen({super.key});@override Widget build(BuildContext context){final items=context.watch<MediaProvider>().library.where((x)=>x.notes.trim().isNotEmpty).toList();if(items.isEmpty)return const Center(child:Text('لا توجد ملاحظات بعد'));return ListView.builder(itemCount:items.length,itemBuilder:(_,i){final x=items[i];return ListTile(leading:x.posterUrl==null?const Icon(Icons.movie):Image.network(x.posterUrl!,width:45,fit:BoxFit.cover),title:Text(x.title),subtitle:Text(x.notes,maxLines:2,overflow:TextOverflow.ellipsis),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>DetailScreen(item:x)));});}}
