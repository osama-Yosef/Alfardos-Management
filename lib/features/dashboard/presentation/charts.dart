import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accounting/posting.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../settings/application/settings_providers.dart';
import '../domain/stats.dart';

class ChartSeries {
  const ChartSeries(this.label, this.color, this.value);
  final String label;
  final Color color;
  final int Function(PostingMetrics m) value;
}

/// Legend row shown above a chart.
class ChartLegend extends StatelessWidget {
  const ChartLegend(this.series, {super.key});
  final List<ChartSeries> series;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      children: [
        for (final s in series)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 6),
            Text(s.label, style: Theme.of(context).textTheme.bodySmall),
          ]),
      ],
    );
  }
}

double _niceMax(double v) {
  if (v <= 0) return 1;
  final exp = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
  final f = v / exp;
  final nice = f <= 1 ? 1 : f <= 2 ? 2 : f <= 5 ? 5 : 10;
  return nice * exp;
}

FlTitlesData _titles(List<SeriesPoint> points, MoneyFormatter fmt, {bool bars = false}) {
  final step = math.max(1, (points.length / 7).ceil());
  return FlTitlesData(
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 46,
        getTitlesWidget: (v, meta) => SideTitleWidget(
          meta: meta,
          child: Text(fmt.compact(Money.fromMajor(v)), style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
        ),
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 26,
        interval: 1,
        getTitlesWidget: (v, meta) {
          final i = v.toInt();
          if (i < 0 || i >= points.length || i % step != 0) return const SizedBox.shrink();
          return SideTitleWidget(
            meta: meta,
            child: Text(points[i].label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
          );
        },
      ),
    ),
  );
}

FlGridData get _grid => FlGridData(
      drawVerticalLine: false,
      getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.divider, strokeWidth: 1),
    );

/// Multi-series line chart over time (amounts in minor units).
class TrendLineChart extends ConsumerWidget {
  const TrendLineChart({super.key, required this.points, required this.series, this.height = 240});

  final List<SeriesPoint> points;
  final List<ChartSeries> series;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = ref.watch(moneyFormatterProvider);
    var maxY = 0.0;
    var minY = 0.0;
    for (final p in points) {
      for (final s in series) {
        final v = Money.toMajor(s.value(p.metrics));
        maxY = math.max(maxY, v);
        minY = math.min(minY, v);
      }
    }
    maxY = _niceMax(maxY);
    if (minY < 0) minY = -_niceMax(-minY);

    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        height: height,
        child: LineChart(
          LineChartData(
            minY: minY,
            maxY: maxY,
            gridData: _grid,
            borderData: FlBorderData(show: false),
            titlesData: _titles(points, fmt),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => AppColors.textPrimary,
                getTooltipItems: (spots) => [
                  for (final s in spots)
                    LineTooltipItem(
                      '${series[s.barIndex].label}: ${fmt(Money.fromMajor(s.y))}',
                      TextStyle(color: Colors.white,
                          fontFamily: AppTheme.fontFamily, fontSize: 11),
                    ),
                ],
              ),
            ),
            lineBarsData: [
              for (final s in series)
                LineChartBarData(
                  isCurved: true,
                  preventCurveOverShooting: true,
                  color: s.color,
                  barWidth: 2.4,
                  dotData: FlDotData(show: points.length <= 14),
                  belowBarData: BarAreaData(show: series.length == 1, color: s.color.withValues(alpha: 0.08)),
                  spots: [
                    for (var i = 0; i < points.length; i++)
                      FlSpot(i.toDouble(), Money.toMajor(s.value(points[i].metrics))),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grouped bar chart over time.
class TrendBarChart extends ConsumerWidget {
  const TrendBarChart({super.key, required this.points, required this.series, this.height = 240});

  final List<SeriesPoint> points;
  final List<ChartSeries> series;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = ref.watch(moneyFormatterProvider);
    var maxY = 0.0;
    for (final p in points) {
      for (final s in series) {
        maxY = math.max(maxY, Money.toMajor(s.value(p.metrics)));
      }
    }
    final rodWidth = math.max(3.0, math.min(14.0, 300 / (points.length * series.length + 1)));
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        height: height,
        child: BarChart(
          BarChartData(
            maxY: _niceMax(maxY),
            gridData: _grid,
            borderData: FlBorderData(show: false),
            titlesData: _titles(points, fmt, bars: true),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => AppColors.textPrimary,
                getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
                  '${points[group.x].label}\n${series[ri].label}: ${fmt(Money.fromMajor(rod.toY))}',
                  const TextStyle(color: Colors.white, fontFamily: AppTheme.fontFamily, fontSize: 11),
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < points.length; i++)
                BarChartGroupData(
                  x: i,
                  barsSpace: 2,
                  barRods: [
                    for (final s in series)
                      BarChartRodData(
                        toY: Money.toMajor(s.value(points[i].metrics)),
                        color: s.color,
                        width: rodWidth,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
