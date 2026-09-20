import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/media_provider.dart';
import 'detail_screen.dart';
import 'search_screen.dart';

class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final items = context.watch<MediaProvider>().library
        .where((item) => item.notes.trim().isNotEmpty).toList();
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.note_alt_outlined, size: 64,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 14),
              Text('لا توجد ملاحظات بعد',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text('أضف عملاً إلى مكتبتك، ثم افتح تفاصيله واكتب ملاحظتك.',
                  textAlign: TextAlign.center),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SearchScreen()),
                ),
                icon: const Icon(Icons.add),
                label: const Text('ابحث عن عمل لإضافة ملاحظة'),
              ),
            ],
          ),
        ),
      );
    }
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
