import 'package:flutter/material.dart';

class CustomDrawer extends StatelessWidget {
  const CustomDrawer({
    super.key,
    this.userName = '🌝 moon 🌝',
    this.avatarUrl,
    this.selectedIndex = 0,
    this.onItemSelected,
    this.onNotifications,
  });

  final String userName;
  final String? avatarUrl;
  final int selectedIndex;
  final ValueChanged<int>? onItemSelected;
  final VoidCallback? onNotifications;

  static const _items = <({
    IconData icon,
    String title,
  })>[
    (icon: Icons.local_fire_department_rounded, title: 'آخر التحديثات'),
    (icon: Icons.list_alt_rounded, title: 'لائحة الأنمي'),
    (icon: Icons.calendar_month_rounded, title: 'المواسم'),
    (icon: Icons.public_rounded, title: 'التقييم العالمي'),
    (icon: Icons.language_rounded, title: 'التقييم العربي'),
    (icon: Icons.bookmark_rounded, title: 'قائمتي'),
    (icon: Icons.dashboard_customize_rounded, title: 'القائمة المخصصة'),
    (icon: Icons.favorite_rounded, title: 'أنمياتي المفضلة'),
    (icon: Icons.favorite_rounded, title: 'شخصياتي المفضلة'),
    (icon: Icons.history_rounded, title: 'آخر المشاهدات'),
    (icon: Icons.download_rounded, title: 'تحميلاتي'),
    (icon: Icons.people_alt_rounded, title: 'الشخصيات الأكثر شعبية'),
    (icon: Icons.extension_rounded, title: 'التوصيات'),
    (icon: Icons.event_rounded, title: 'مواعيد نزول الحلقات'),
    (icon: Icons.settings_rounded, title: 'الإعدادات'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Drawer(
        elevation: 24,
        width: (MediaQuery.sizeOf(context).width * .84).clamp(280.0, 360.0),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'الإشعارات',
                          onPressed: onNotifications,
                          icon: const Icon(Icons.notifications_none_rounded),
                        ),
                        const Spacer(),
                      ],
                    ),
                    CircleAvatar(
                      radius: 38,
                      backgroundColor: scheme.primaryContainer,
                      backgroundImage: avatarUrl != null &&
                              avatarUrl!.trim().isNotEmpty
                          ? NetworkImage(avatarUrl!)
                          : null,
                      child: avatarUrl == null || avatarUrl!.trim().isEmpty
                          ? Icon(
                              Icons.person_rounded,
                              size: 38,
                              color: scheme.onPrimaryContainer,
                            )
                          : null,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      userName,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ScrollbarTheme(
                  data: ScrollbarThemeData(
                    thumbColor: WidgetStatePropertyAll(Colors.transparent),
                    trackColor: WidgetStatePropertyAll(Colors.transparent),
                  ),
                  child: Scrollbar(
                    child: ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    final hasDividerBefore = index == 5 || index == 14;

                    return Column(
                      children: [
                        if (hasDividerBefore)
                          const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            child: Divider(),
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: ListTile(
                            selected: selectedIndex == index,
                            selectedTileColor: scheme.primaryContainer,
                            selectedColor: scheme.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13),
                            ),
                            leading: Icon(item.icon),
                            title: Text(
                              item.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            onTap: () {
                              Navigator.of(context).pop();
                              onItemSelected?.call(index);
                            },
                          ),
                        ),
                      ],
                    );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
