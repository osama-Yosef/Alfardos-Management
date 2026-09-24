import 'package:intl/intl.dart';

/// Date helpers. Financial documents store the business date as a Timestamp
/// plus a `dayKey` string (yyyy-MM-dd, local time) used for daily statistics.
abstract final class Dates {
  static final _dayKey = DateFormat('yyyy-MM-dd', 'en');
  static final _display = DateFormat('yyyy/MM/dd', 'en');
  static final _displayTime = DateFormat('yyyy/MM/dd  HH:mm', 'en');
  static final _dayMonth = DateFormat('d/M', 'en');

  static String dayKey(DateTime d) => _dayKey.format(d);
  static DateTime parseDayKey(String key) => _dayKey.parse(key);

  static String format(DateTime d) => _display.format(d);
  static String formatTime(DateTime d) => _displayTime.format(d);
  static String dayMonth(DateTime d) => _dayMonth.format(d);

  static DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
  static DateTime endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  static DateTime startOfMonth(DateTime d) => DateTime(d.year, d.month);

  /// Saturday-based week start, as commonly used in Arabic-speaking markets.
  static DateTime startOfWeek(DateTime d) {
    final day = startOfDay(d);
    return DateTime(day.year, day.month, day.day - (day.weekday + 1) % 7);
  }

  /// Keeps the time-of-day of "now" when the user picks today's date so that
  /// documents created the same day keep their natural order.
  static DateTime withCurrentTime(DateTime date) {
    final now = DateTime.now();
    if (startOfDay(date) == startOfDay(now)) return now;
    return DateTime(date.year, date.month, date.day, 12);
  }

  static const arabicMonths = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];

  static String monthName(int month) => arabicMonths[month - 1];

  static Iterable<DateTime> daysInRange(DateTime from, DateTime to) sync* {
    var d = startOfDay(from);
    final end = startOfDay(to);
    while (!d.isAfter(end)) {
      yield d;
      d = DateTime(d.year, d.month, d.day + 1);
    }
  }
}

/// A closed date range [from, to] at day granularity.
class DateRange {
  DateRange(DateTime from, DateTime to)
      : from = Dates.startOfDay(from),
        to = Dates.endOfDay(to);

  final DateTime from;
  final DateTime to;

  int get days => to.difference(from).inDays + 1;

  bool contains(DateTime d) => !d.isBefore(from) && !d.isAfter(to);

  String get label => Dates.format(from) == Dates.format(to)
      ? Dates.format(from)
      : '${Dates.format(from)} - ${Dates.format(to)}';

  @override
  bool operator ==(Object other) =>
      other is DateRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}

/// Preset periods offered by the dashboard and reports.
enum PeriodPreset {
  today('اليوم'),
  week('هذا الأسبوع'),
  month('هذا الشهر'),
  last3Months('آخر 3 أشهر'),
  year('هذه السنة'),
  custom('فترة مخصصة');

  const PeriodPreset(this.label);
  final String label;

  DateRange range([DateTime? now]) {
    final n = now ?? DateTime.now();
    return switch (this) {
      today => DateRange(n, n),
      week => DateRange(Dates.startOfWeek(n), n),
      month => DateRange(Dates.startOfMonth(n), n),
      last3Months => DateRange(DateTime(n.year, n.month - 2), n),
      year => DateRange(DateTime(n.year), n),
      custom => DateRange(Dates.startOfMonth(n), n),
    };
  }
}
