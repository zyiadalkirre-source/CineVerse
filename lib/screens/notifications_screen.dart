import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/database_service.dart';
import '../services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _db = DatabaseService.instance;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await _db.getNotifications();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _markRead() async {
    await _db.markAllNotificationsRead();
    await _load();
  }

  Future<void> _clear() async {
    await _db.clearNotifications();
    await _load();
  }

  Future<void> _requestPermission() async {
    await NotificationService.requestPermission();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم طلب صلاحية الإشعارات.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unread = _items.where((x) => (x['read'] ?? 0) == 0).length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('الإشعارات${unread > 0 ? ' ($unread)' : ''}'),
          actions: [
            IconButton(
              tooltip: 'صلاحية الإشعارات',
              onPressed: _requestPermission,
              icon: const Icon(Icons.notifications_active_outlined),
            ),
            IconButton(
              tooltip: 'تحديد الكل كمقروء',
              onPressed: _items.isEmpty ? null : _markRead,
              icon: const Icon(Icons.done_all_rounded),
            ),
            IconButton(
              tooltip: 'مسح',
              onPressed: _items.isEmpty ? null : _clear,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(28),
                      child: Text(
                        'لا توجد إشعارات حالياً. سيتم حفظ تنبيهات الحلقات الجديدة هنا.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final row = _items[i];
                        final date = DateTime.fromMillisecondsSinceEpoch(
                          (row['created_at'] as int?) ?? 0,
                        );
                        final isUnread = (row['read'] ?? 0) == 0;

                        return Card(
                          child: ListTile(
                            leading: Icon(
                              isUnread
                                  ? Icons.notifications_active
                                  : Icons.notifications_none,
                            ),
                            title: Text(
                              (row['title'] ?? '').toString(),
                              style: TextStyle(
                                fontWeight: isUnread
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              '${(row['body'] ?? '').toString()}\n${DateFormat('yyyy/MM/dd HH:mm').format(date)}',
                            ),
                            isThreeLine: true,
                            onTap: isUnread
                                ? () async {
                                    await _db.markAllNotificationsRead();
                                    await _load();
                                  }
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}
