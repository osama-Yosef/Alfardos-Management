import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/export/exporter.dart';
import '../../../core/money/money.dart';
import '../../../core/pdf/pdf_documents.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/keywords.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/fields.dart';
import '../../../core/widgets/live_query_list.dart';
import '../../../core/widgets/money_text.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/period_selector.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../core/widgets/states.dart';
import '../../dashboard/domain/activity.dart';
import '../../dashboard/presentation/activity_list.dart';
import '../../settings/application/settings_providers.dart';
import '../application/report_providers.dart';
import '../domain/report_data.dart';
import '../domain/report_type.dart';

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key, required this.type});

  final ReportType type;

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  Period _period = Period.of(PeriodPreset.month);
  String _search = '';
  int? _sortColumn;
  bool _sortAsc = true;

  DateRange get _range => widget.type.usesPeriod ? _period.range : PeriodPreset.today.range();

  String _cellText(Object? v, CellType type, MoneyFormatter fmt) => switch (v) {
        null => '',
        final int i when type == CellType.money => fmt(i),
        final DateTime d => Dates.format(d),
        final double d => formatQuantity(d),
        final num n => n.toString(),
        _ => v.toString(),
      };

  List<int> _visibleRows(ReportData data, MoneyFormatter fmt) {
    final term = Keywords.normalize(_search);
    final idx = [
      for (var i = 0; i < data.rows.length; i++)
        if (term.isEmpty ||
            data.rows[i].any((c) => c is String && Keywords.normalize(c).contains(term)))
          i,
    ];
    if (_sortColumn != null) {
      int cmp(Object? a, Object? b) {
        if (a == null) return b == null ? 0 : -1;
        if (b == null) return 1;
        if (a is num && b is num) return a.compareTo(b);
        if (a is DateTime && b is DateTime) return a.compareTo(b);
        return a.toString().compareTo(b.toString());
      }

      idx.sort((x, y) {
        final r = cmp(data.rows[x][_sortColumn!], data.rows[y][_sortColumn!]);
        return _sortAsc ? r : -r;
      });
    }
    return idx;
  }

  String get _subtitle => widget.type.usesPeriod ? 'الفترة: ${_period.range.label}' : 'حتى ${Dates.format(DateTime.now())}';

  void _exportPdf(ReportData data, MoneyFormatter fmt) {
    final rows = _visibleRows(data, fmt);
    Exporter.pdfActions(
      context,
      fileName: widget.type.title,
      build: () => PdfDocuments.report(
        settings: ref.read(companySettingsProvider),
        title: widget.type.title,
        subtitle: _subtitle,
        summary: [
          for (final k in data.kpis) (k.label, k.isMoney ? fmt(k.amount.toInt()) : _num(k.amount)),
        ],
        tables: [
          ReportTable(
            headers: [for (final c in data.columns) c.label],
            numeric: {for (var i = 0; i < data.columns.length; i++) if (data.columns[i].numeric) i},
            rows: [
              for (final r in rows)
                [for (var c = 0; c < data.columns.length; c++) _cellText(data.rows[r][c], data.columns[c].type, fmt)],
            ],
            footer: data.footer == null
                ? null
                : [for (var c = 0; c < data.columns.length; c++) _cellText(data.footer![c], data.columns[c].type, fmt)],
          ),
          if (data.secondaryRows.isNotEmpty)
            ReportTable(
              title: data.secondaryTitle,
              headers: [for (final c in data.secondaryColumns) c.label],
              numeric: {for (var i = 0; i < data.secondaryColumns.length; i++) if (data.secondaryColumns[i].numeric) i},
              rows: [
                for (final r in data.secondaryRows)
                  [for (var c = 0; c < r.length; c++) _cellText(r[c], data.secondaryColumns[c].type, fmt)],
              ],
            ),
        ],
      ),
    );
  }

  void _exportCsv(ReportData data, MoneyFormatter fmt) {
    final rows = _visibleRows(data, fmt);
    Object? raw(Object? v, CellType t) => switch (v) {
          final int i when t == CellType.money => Money.toMajor(i),
          final DateTime d => Dates.format(d),
          _ => v,
        };
    Exporter.saveCsv(context, '${widget.type.title} ${Dates.dayKey(DateTime.now())}', [
      [for (final c in data.columns) c.label],
      for (final r in rows) [for (var c = 0; c < data.columns.length; c++) raw(data.rows[r][c], data.columns[c].type)],
      if (data.footer != null) [for (var c = 0; c < data.columns.length; c++) raw(data.footer![c], data.columns[c].type)],
    ]);
  }

  static String _num(num v) => v is double ? formatQuantity(v) : v.toString();

  @override
  Widget build(BuildContext context) {
    final type = widget.type;
    if (type == ReportType.journal) return _JournalReport(period: _period, onPeriod: (p) => setState(() => _period = p));

    final report = ref.watch(reportProvider((type, _range)));
    final fmt = ref.watch(moneyFormatterProvider);

    return PageScaffold(
      title: type.title,
      subtitle: _subtitle,
      actions: [
        if (report.hasValue) ...[
          IconButton(
            tooltip: 'تصدير Excel (CSV)',
            onPressed: () => _exportCsv(report.value!, fmt),
            icon: const Icon(Symbols.table_view),
          ),
          FilledButton.tonalIcon(
            onPressed: () => _exportPdf(report.value!, fmt),
            icon: const Icon(Symbols.picture_as_pdf),
            label: const Text('PDF'),
          ),
        ],
        IconButton(
          tooltip: 'تحديث',
          onPressed: () => ref.invalidate(reportProvider((type, _range))),
          icon: const Icon(Symbols.refresh),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (type.usesPeriod) ...[
            PeriodSelector(value: _period, onChanged: (p) => setState(() => _period = p)),
            const SizedBox(height: 14),
          ],
          AsyncView<ReportData>(
            value: report,
            onRetry: () => ref.invalidate(reportProvider((type, _range))),
            data: (data) => _body(data, fmt),
          ),
        ],
      ),
    );
  }

  Widget _body(ReportData data, MoneyFormatter fmt) {
    final rows = _visibleRows(data, fmt);
    Widget cell(Object? v, ReportColumn c, {bool bold = false}) {
      final style = TextStyle(fontWeight: bold ? FontWeight.w700 : null);
      if (v is int && c.type == CellType.money) {
        return MoneyText(v, style: style, tone: v < 0 ? Tone.danger : null);
      }
      return Text(_cellText(v, c.type, fmt), style: style, overflow: TextOverflow.ellipsis);
    }

    Widget table(List<ReportColumn> columns, List<List<Object?>> data, List<int> order,
        {List<Object?>? footer, bool sortable = false, List<String?>? routes}) {
      final minWidth = columns.length * 120.0;
      return Card(
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(builder: (context, constraints) {
          final width = constraints.maxWidth > minWidth ? constraints.maxWidth : minWidth;
          final content = SizedBox(
            width: width,
            child: Column(
              children: [
                Container(
                  color: AppColors.surfaceAlt,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(children: [
                    for (var i = 0; i < columns.length; i++)
                      Expanded(
                        flex: columns[i].flex,
                        child: InkWell(
                          onTap: !sortable
                              ? null
                              : () => setState(() {
                                    if (_sortColumn == i) {
                                      _sortAsc = !_sortAsc;
                                    } else {
                                      _sortColumn = i;
                                      _sortAsc = !columns[i].numeric;
                                    }
                                  }),
                          child: Row(
                            mainAxisAlignment: columns[i].numeric ? MainAxisAlignment.end : MainAxisAlignment.start,
                            children: [
                              Flexible(
                                child: Text(columns[i].label,
                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                              ),
                              if (sortable && _sortColumn == i)
                                Icon(_sortAsc ? Symbols.arrow_upward : Symbols.arrow_downward, size: 14),
                            ],
                          ),
                        ),
                      ),
                  ]),
                ),
                if (order.isEmpty)
                  const Padding(padding: EdgeInsets.all(28), child: Text('لا توجد بيانات في هذه الفترة')),
                for (final r in order) ...[
                  const Divider(),
                  InkWell(
                    onTap: routes?[r] == null ? null : () => context.push(routes![r]!),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                      child: Row(children: [
                        for (var c = 0; c < columns.length; c++)
                          Expanded(
                            flex: columns[c].flex,
                            child: Align(
                              alignment: columns[c].numeric ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
                              child: cell(data[r][c], columns[c]),
                            ),
                          ),
                      ]),
                    ),
                  ),
                ],
                if (footer != null) ...[
                  const Divider(),
                  Container(
                    color: AppColors.surfaceAlt,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                    child: Row(children: [
                      for (var c = 0; c < columns.length; c++)
                        Expanded(
                          flex: columns[c].flex,
                          child: Align(
                            alignment: columns[c].numeric ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
                            child: cell(footer[c], columns[c], bold: true),
                          ),
                        ),
                    ]),
                  ),
                ],
              ],
            ),
          );
          return width > constraints.maxWidth
              ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: content)
              : content;
        }),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ResponsiveGrid(
          minItemWidth: 190,
          children: [
            for (final k in data.kpis)
              StatCard(
                label: k.label,
                icon: Symbols.analytics,
                tone: k.tone,
                amount: k.isMoney ? k.amount.toInt() : null,
                value: k.isMoney ? null : _num(k.amount),
              ),
          ],
        ),
        if (data.note != null) ...[
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Symbols.info, size: 16, color: AppColors.info),
            const SizedBox(width: 6),
            Expanded(child: Text(data.note!, style: Theme.of(context).textTheme.bodySmall)),
          ]),
        ],
        const SizedBox(height: 14),
        if (data.rows.length > 5) ...[
          SizedBox(
            width: context.isMobile ? double.infinity : 340,
            child: SearchField(onChanged: (v) => setState(() => _search = v), hint: 'بحث داخل التقرير...'),
          ),
          const SizedBox(height: 10),
        ],
        table(data.columns, data.rows, rows, footer: data.footer, sortable: true, routes: data.routes),
        if (data.secondaryRows.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(data.secondaryTitle ?? '', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          table(data.secondaryColumns, data.secondaryRows, [for (var i = 0; i < data.secondaryRows.length; i++) i]),
        ],
      ],
    );
  }
}

/// Journal of all financial transactions (live, paginated).
class _JournalReport extends ConsumerWidget {
  const _JournalReport({required this.period, required this.onPeriod});

  final Period period;
  final ValueChanged<Period> onPeriod;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PageScaffold(
      title: ReportType.journal.title,
      subtitle: 'كل قيد مالي مسجل في النظام، بما فيها قيود الإلغاء',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PeriodSelector(value: period, onChanged: onPeriod),
          const SizedBox(height: 12),
          LiveQueryList<Activity>(
            query: ref.watch(reportsRepositoryProvider).journalQuery(period.range),
            fromDoc: Activity.fromDoc,
            pageSize: 40,
            empty: const EmptyState(icon: Symbols.list_alt, title: 'لا توجد حركات في هذه الفترة'),
            itemBuilder: (_, a, _) => ActivityTile(activity: a),
          ),
          const SizedBox(height: 8),
          AppCard(
            child: Text(
              'السجل غير قابل للتعديل أو الحذف. أي تصحيح يتم بقيد إلغاء عكسي يظهر هنا بتاريخه.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
