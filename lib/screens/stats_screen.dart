import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/media_provider.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<MediaProvider>().stats;
    final sections = stats.totalWatched == 0
        ? [PieChartSectionData(value: 1, title: '0', radius: 55)]
        : <PieChartSectionData>[
            if (stats.movies > 0)
              PieChartSectionData(value: stats.movies.toDouble(), title: 'أفلام', radius: 55),
            if (stats.tvShows > 0)
              PieChartSectionData(value: stats.tvShows.toDouble(), title: 'مسلسلات', radius: 55),
            if (stats.anime > 0)
              PieChartSectionData(value: stats.anime.toDouble(), title: 'أنمي', radius: 55),
          ];

    final genres = stats.topGenres.entries.toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('الإحصائيات', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 700 ? 3 : 2;
            final gap = 10.0;
            final cardWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                _statCard('تمت المشاهدة', stats.totalWatched.toString(), cardWidth),
                _statCard('قيد المشاهدة', stats.totalWatching.toString(), cardWidth),
                _statCard('قائمة الانتظار', stats.totalWatchlist.toString(), cardWidth),
                _statCard('الساعات', stats.totalHours.toStringAsFixed(1), cardWidth),
                _statCard('متوسط تقييمي', stats.averageRating.toStringAsFixed(1), constraints.maxWidth),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text('توزيع المكتبة'),
                const SizedBox(height: 220),
                SizedBox(
                  height: 220,
                  child: PieChart(
                    PieChartData(
                      sections: sections,
                      centerSpaceRadius: 45,
                    ),
                  ),
                ),
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
                  const Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text('الأنواع الأكثر مشاهدة'),
                  ),
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
                                  toY: genres[i].value.toDouble(), width: 18),
                              ],
                            ),
                        ],
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final i = value.toInt();
                                return Text(
                                  i >= 0 && i < genres.length
                                      ? genres[i].key : '',
                                  style: const TextStyle(fontSize: 9),
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
        const SizedBox(height: 12),
        Text('الممثلون الأكثر ظهوراً',
            style: Theme.of(context).textTheme.titleLarge),
        ...stats.topActors.entries.map(
          (entry) => ListTile(
            title: Text(entry.key),
            trailing: Text(entry.value.toString()),
          ),
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, double width) {
    return SizedBox(
      width: width,
      child: Card(
        child: ListTile(
          title: Text(label, style: const TextStyle(fontSize: 12)),
          subtitle: Text(value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
