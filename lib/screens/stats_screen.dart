import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/media_provider.dart';

List<List<int>> statisticsGridRows(int itemCount, {int columns = 2}) {
  if (itemCount <= 0) return const [];
  if (columns <= 0) {
    throw ArgumentError.value(columns, 'columns', 'must be greater than zero');
  }
  final rows = <List<int>>[];
  for (var start = 0; start < itemCount; start += columns) {
    final row = <int>[];
    for (var i = start; i < itemCount && i < start + columns; i++) {
      row.add(i);
    }
    rows.add(row);
  }
  return rows;
}

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<MediaProvider>().stats;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final chartColors = <Color>[
      colors.primary,
      colors.secondary,
      colors.tertiary,
    ];

    final sections = stats.totalWatched == 0
        ? [
            PieChartSectionData(
              value: 1,
              title: '',
              radius: 44,
              color: colors.onSurface.withOpacity(.10),
              showTitle: false,
            ),
          ]
        : <PieChartSectionData>[
            if (stats.movies > 0)
              PieChartSectionData(
                value: stats.movies.toDouble(),
                title: '',
                radius: 54,
                color: chartColors[0],
                showTitle: false,
              ),
            if (stats.tvShows > 0)
              PieChartSectionData(
                value: stats.tvShows.toDouble(),
                title: '',
                radius: 54,
                color: chartColors[1],
                showTitle: false,
              ),
            if (stats.anime > 0)
              PieChartSectionData(
                value: stats.anime.toDouble(),
                title: '',
                radius: 54,
                color: chartColors[2],
                showTitle: false,
              ),
          ];

    final genres = stats.topGenres.entries.toList();
    final statCards = [
      _statCard('تمت المشاهدة', stats.totalWatched.toString(), colors.primary),
      _statCard('قيد المشاهدة', stats.totalWatching.toString(), colors.secondary),
      _statCard('قائمة الانتظار', stats.totalWatchlist.toString(), colors.tertiary),
      _statCard('الساعات', stats.totalHours.toStringAsFixed(1), colors.primary),
      _statCard('متوسط تقييمي', stats.averageRating.toStringAsFixed(1), colors.secondary),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('الإحصائيات', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 14),
        Column(
          children: [
            for (final row in statisticsGridRows(statCards.length))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < row.length; i++) ...[
                      Expanded(child: statCards[row[i]]),
                      if (i < row.length - 1) const SizedBox(width: 10),
                    ],
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            child: Column(
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    'توزيع المكتبة',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 220,
                  child: PieChart(
                    PieChartData(
                      sections: sections,
                      centerSpaceRadius: 46,
                      sectionsSpace: stats.totalWatched == 0 ? 0 : 3,
                      borderData: FlBorderData(show: false),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 16,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    _legendItem(context, chartColors[0], 'أفلام', stats.movies),
                    _legendItem(context, chartColors[1], 'مسلسلات', stats.tvShows),
                    _legendItem(context, chartColors[2], 'أنمي', stats.anime),
                  ],
                ),
                if (stats.totalWatched == 0) ...[
                  const SizedBox(height: 14),
                  Text(
                    'لا توجد بيانات كافية بعد. ستظهر نسب التوزيع هنا بعد مشاهدة أعمال.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (genres.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      'الأنواع الأكثر مشاهدة',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 220,
                    child: BarChart(
                      BarChartData(
                        borderData: FlBorderData(show: false),
                        barGroups: [
                          for (var i = 0; i < genres.length; i++)
                            BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(
                                  toY: genres[i].value.toDouble(),
                                  width: 18,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ],
                            ),
                        ],
                        titlesData: FlTitlesData(
                          leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) {
                                final i = value.toInt();
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: SizedBox(
                                    width: 52,
                                    child: Text(
                                      i >= 0 && i < genres.length ? genres[i].key : '',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 9),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 18),
        Text('الممثلون الأكثر ظهوراً', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        if (stats.topActors.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
              child: Column(
                children: [
                  Icon(Icons.groups_2_outlined, size: 42, color: colors.primary),
                  const SizedBox(height: 10),
                  Text(
                    'لا توجد بيانات للممثلين بعد',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'أضف أعمالاً إلى مكتبتك وشاهدها لتظهر هنا أكثر الأسماء تكراراً.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ...stats.topActors.entries.map(
                  (entry) => ListTile(
                    title: Text(entry.key),
                    trailing: Text(
                      entry.value.toString(),
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _statCard(String label, String value, Color accent) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 3,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                value,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(BuildContext context, Color color, String label, int value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text('$label ($value)', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
