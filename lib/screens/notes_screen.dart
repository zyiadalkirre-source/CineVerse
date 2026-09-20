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
        .where((item) => item.notes.trim().isNotEmpty)
        .toList();

    if (items.isEmpty) {
      final theme = Theme.of(context);
      final colors = theme.colorScheme;

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.primary.withOpacity(.10),
                    ),
                    child: Icon(
                      Icons.note_alt_outlined,
                      size: 38,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'لا توجد ملاحظات بعد',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'أضف عملاً إلى مكتبتك، ثم افتح تفاصيله واكتب ملاحظتك.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SearchScreen()),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('إضافة ملاحظة جديدة'),
                    ),
                  ),
                ],
              ),
            ),
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
            context,
            MaterialPageRoute(builder: (_) => DetailScreen(item: item)),
          ),
        );
      },
    );
  }
}
