import '../../../core/accounting/posting.dart';
import '../../../core/utils/dates.dart';

/// Aggregated metrics of one calendar day (`daily_stats/{yyyy-MM-dd}`),
/// maintained atomically by the ledger with every posting.
class DailyStat {
  const DailyStat(this.day, this.metrics);
  final DateTime day;
  final PostingMetrics metrics;
}

enum Bucket { day, month }

class SeriesPoint {
  const SeriesPoint(this.start, this.label, this.metrics);
  final DateTime start;
  final String label;
  final PostingMetrics metrics;
}

/// Pure aggregation helpers used by the dashboard and reports.
abstract final class StatsMath {
  static PostingMetrics total(Iterable<DailyStat> stats, [DateRange? range]) {
    var sum = PostingMetrics.zero;
    for (final s in stats) {
      if (range == null || range.contains(s.day)) sum = sum + s.metrics;
    }
    return sum;
  }

  static Bucket bucketFor(DateRange range) => range.days <= 62 ? Bucket.day : Bucket.month;

  /// Continuous series over [range] (empty days/months included as zeros so
  /// charts show real gaps instead of connecting distant points).
  static List<SeriesPoint> series(Iterable<DailyStat> stats, DateRange range) {
    final bucket = bucketFor(range);
    final byKey = <DateTime, PostingMetrics>{};
    DateTime keyOf(DateTime d) => bucket == Bucket.day ? Dates.startOfDay(d) : DateTime(d.year, d.month);
    for (final s in stats) {
      if (!range.contains(s.day)) continue;
      final k = keyOf(s.day);
      byKey[k] = (byKey[k] ?? PostingMetrics.zero) + s.metrics;
    }
    final points = <SeriesPoint>[];
    if (bucket == Bucket.day) {
      for (final d in Dates.daysInRange(range.from, range.to)) {
        points.add(SeriesPoint(d, Dates.dayMonth(d), byKey[d] ?? PostingMetrics.zero));
      }
    } else {
      var m = DateTime(range.from.year, range.from.month);
      final end = DateTime(range.to.year, range.to.month);
      while (!m.isAfter(end)) {
        points.add(SeriesPoint(m, Dates.monthName(m.month), byKey[m] ?? PostingMetrics.zero));
        m = DateTime(m.year, m.month + 1);
      }
    }
    return points;
  }
}
