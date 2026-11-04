import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/categories.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';

/// Donut chart for the category breakdown with a tappable legend.
class CategoryDonutCard extends StatefulWidget {
  const CategoryDonutCard({super.key, required this.byCategory});
  final Map<String, double> byCategory;

  @override
  State<CategoryDonutCard> createState() => _CategoryDonutCardState();
}

class _CategoryDonutCardState extends State<CategoryDonutCard> {
  int _touched = -1;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final entries = widget.byCategory.entries.where((e) => e.value > 0).toList();
    final total = entries.fold<double>(0, (s, e) => s + e.value);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('By category', style: t.titleMedium),
          const SizedBox(height: 8),
          if (total == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('No spending in this period', style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant))),
            )
          else ...[
            SizedBox(
              height: 200,
              child: Stack(alignment: Alignment.center, children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 62,
                    startDegreeOffset: -90,
                    pieTouchData: PieTouchData(touchCallback: (event, resp) {
                      setState(() {
                        _touched = !event.isInterestedForInteractions || resp?.touchedSection == null
                            ? -1
                            : resp!.touchedSection!.touchedSectionIndex;
                      });
                    }),
                    sections: [
                      for (var i = 0; i < entries.length; i++)
                        PieChartSectionData(
                          value: entries[i].value,
                          color: styleFor(entries[i].key).color,
                          radius: i == _touched ? 30 : 24,
                          showTitle: false,
                        ),
                    ],
                  ),
                ),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_touched >= 0 && _touched < entries.length ? entries[_touched].key : 'Total',
                      style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  Text(
                    inrCompact(_touched >= 0 && _touched < entries.length ? entries[_touched].value : total),
                    style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800, fontFeatures: tabular),
                  ),
                ]),
              ]),
            ),
            const SizedBox(height: 12),
            for (final e in entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: styleFor(e.key).color, borderRadius: BorderRadius.circular(3)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(e.key, style: t.bodyMedium)),
                  Text('${(e.value / total * 100).toStringAsFixed(0)}%',
                      style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant, fontFeatures: tabular)),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 84,
                    child: Text(inr(e.value),
                        textAlign: TextAlign.right,
                        style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w700, fontFeatures: tabular)),
                  ),
                ]),
              ),
          ],
        ]),
      ),
    );
  }
}

class NeedWantCard extends StatelessWidget {
  const NeedWantCard({super.key, required this.byType});
  final Map<String, double> byType;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final need = byType['Need'] ?? 0;
    final want = byType['Want'] ?? 0;
    final total = need + want;

    Widget legend(String label, double v, Color c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 8),
            Text(label, style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
          ]),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(inrCompact(v), style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800, fontFeatures: tabular)),
          ),
          Text(total == 0 ? '0%' : '${(v / total * 100).toStringAsFixed(0)}%',
              style: t.bodySmall?.copyWith(color: c, fontWeight: FontWeight.w700)),
        ]);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          SizedBox(
            width: 120,
            height: 120,
            child: PieChart(PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 36,
              startDegreeOffset: -90,
              sections: total == 0
                  ? [PieChartSectionData(value: 1, color: cs.outlineVariant, radius: 18, showTitle: false)]
                  : [
                      PieChartSectionData(value: need, color: kNeedColor, radius: 18, showTitle: false),
                      PieChartSectionData(value: want, color: kWantColor, radius: 18, showTitle: false),
                    ],
            )),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Need vs Want', style: t.titleMedium),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: legend('Need', need, kNeedColor)),
                Expanded(child: legend('Want', want, kWantColor)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class MonthlyBarCard extends StatelessWidget {
  const MonthlyBarCard({super.key, required this.monthly});
  final List<(DateTime, double)> monthly;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final maxV = monthly.fold<double>(0, (m, e) => e.$2 > m ? e.$2 : m);
    final top = maxV == 0 ? 100.0 : maxV * 1.2;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 20, 16, 12),
        child: SizedBox(
          height: 220,
          child: BarChart(
            BarChartData(
              maxY: top,
              alignment: BarChartAlignment.spaceAround,
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: top / 4,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: cs.outlineVariant.withValues(alpha: 0.5), strokeWidth: 1, dashArray: [4, 4]),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => cs.inverseSurface,
                  getTooltipItem: (g, _, rod, _) => BarTooltipItem(
                    '${DateFormat('MMM yyyy').format(monthly[g.x].$1)}\n${inr(rod.toY)}',
                    TextStyle(color: cs.onInverseSurface, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    interval: top / 4,
                    getTitlesWidget: (v, meta) => SideTitleWidget(
                      meta: meta,
                      child: Text(v == 0 ? '0' : inrCompact(v).replaceAll('₹', ''),
                          style: t.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (v, meta) => SideTitleWidget(
                      meta: meta,
                      child: Text(DateFormat('MMM').format(monthly[v.toInt()].$1),
                          style: t.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                    ),
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < monthly.length; i++)
                  BarChartGroupData(x: i, barRods: [
                    BarChartRodData(
                      toY: monthly[i].$2,
                      width: 22,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: i == monthly.length - 1
                            ? const [Color(0xFF5B4BE0), Color(0xFF9C8FFF)]
                            : [AppColors.primary.withValues(alpha: 0.35), AppColors.primary.withValues(alpha: 0.55)],
                      ),
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: top,
                        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                      ),
                    ),
                  ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tiny 7-day bars inside the hero card.
class WeekSparkBars extends StatelessWidget {
  const WeekSparkBars({super.key, required this.daily});
  final List<(DateTime, double)> daily;

  @override
  Widget build(BuildContext context) {
    final maxV = daily.fold<double>(0, (m, e) => e.$2 > m ? e.$2 : m);
    final t = Theme.of(context).textTheme;
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      for (var i = 0; i < daily.length; i++)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              Flexible(
                child: FractionallySizedBox(
                  heightFactor: maxV == 0 ? 0.06 : (daily[i].$2 / maxV).clamp(0.06, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: i == daily.length - 1 ? 0.95 : 0.35),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(DateFormat('E').format(daily[i].$1).substring(0, 1),
                  style: t.labelSmall?.copyWith(color: Colors.white70)),
            ]),
          ),
        ),
    ]);
  }
}
