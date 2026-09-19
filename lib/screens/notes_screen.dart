import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/media_provider.dart';
import 'detail_screen.dart';

class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final items = context.watch<MediaProvider>().library
        .where((item) => item.notes.trim().isNotEmpty).toList();
    if (items.isEmpty) return const Center(child: Text('لا توجد ملاحظات بعد'));
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (_, index) {
        final item = items[index];
        return ListTile(
          leading: item.posterUrl == null
              ? const Icon(Icons.movie)
              : Image.network(item.posterUrl!, width: 45, fit: BoxFit.cover),
          title: Text(item.title),
          subtitle: Text(item.notes, maxLines: 2, overflow: TextOverflow.ellipsis),
          onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => DetailScreen(item: item))),
        );
      },
    );
  }
}
