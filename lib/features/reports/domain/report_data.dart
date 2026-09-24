import '../../../core/theme/app_colors.dart';

enum CellType { text, money, number, date }

class ReportColumn {
  const ReportColumn(this.label, {this.type = CellType.text, this.flex = 1});
  final String label;
  final CellType type;
  final int flex;

  bool get numeric => type != CellType.text && type != CellType.date;
}

class ReportKpi {
  const ReportKpi(this.label, this.amount, {this.tone = Tone.primary, this.isMoney = true});
  final String label;
  final num amount;
  final Tone tone;
  final bool isMoney;
}

/// A computed report: KPI cards, a sortable/searchable table and an
/// optional secondary table. Pure data — rendered on screen, to PDF and CSV.
class ReportData {
  const ReportData({
    required this.kpis,
    required this.columns,
    required this.rows,
    this.footer,
    this.secondaryTitle,
    this.secondaryColumns = const [],
    this.secondaryRows = const [],
    this.note,
    this.routes,
  });

  final List<ReportKpi> kpis;
  final List<ReportColumn> columns;

  /// Cells: String (text), int (money minor units), num (number), DateTime.
  final List<List<Object?>> rows;
  final List<Object?>? footer;
  final String? secondaryTitle;
  final List<ReportColumn> secondaryColumns;
  final List<List<Object?>> secondaryRows;
  final String? note;

  /// Optional in-app route per row (same index as [rows]).
  final List<String?>? routes;
}
