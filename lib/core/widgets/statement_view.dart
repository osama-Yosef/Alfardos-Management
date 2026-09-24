import 'package:flutter/material.dart';

import '../accounting/statement.dart';
import '../theme/app_colors.dart';
import '../utils/dates.dart';
import 'app_card.dart';
import 'app_data_table.dart';
import 'money_text.dart';
import 'responsive.dart';

/// Running-balance statement table shared by customers, suppliers and
/// cashboxes. On phones rows collapse into compact tiles.
class StatementView extends StatelessWidget {
  const StatementView({
    super.key,
    required this.statement,
    required this.increaseLabel,
    required this.decreaseLabel,
    this.increaseTone = Tone.danger,
    this.decreaseTone = Tone.success,
    this.onOpenReference,
  });

  final Statement statement;
  final String increaseLabel;
  final String decreaseLabel;
  final Tone increaseTone;
  final Tone decreaseTone;
  final void Function(StatementEntry entry)? onOpenReference;

  @override
  Widget build(BuildContext context) {
    final summary = ResponsiveGrid(
      minItemWidth: 160,
      children: [
        _Tile('رصيد أول المدة', statement.opening, Tone.neutral),
        _Tile('إجمالي $increaseLabel', statement.totalIncrease, increaseTone),
        _Tile('إجمالي $decreaseLabel', statement.totalDecrease, decreaseTone),
        _Tile('الرصيد الختامي', statement.closing, Tone.primary),
      ],
    );

    Widget body;
    if (context.isMobile) {
      body = Card(
        child: Column(
          children: [
            for (var i = statement.rows.length - 1; i >= 0; i--) ...[
              if (i != statement.rows.length - 1) const Divider(),
              _MobileRow(row: statement.rows[i], increaseTone: increaseTone, decreaseTone: decreaseTone),
            ],
            if (statement.rows.isEmpty)
              const Padding(padding: EdgeInsets.all(24), child: Text('لا توجد حركات في هذه الفترة')),
          ],
        ),
      );
    } else {
      body = Card(
        clipBehavior: Clip.antiAlias,
        child: AppDataTable(
          columns: [
            const AppColumn('التاريخ', minWidth: 100),
            const AppColumn('البيان', flex: 3, minWidth: 240),
            const AppColumn('المرجع', minWidth: 100),
            AppColumn(increaseLabel, numeric: true),
            AppColumn(decreaseLabel, numeric: true),
            const AppColumn('الرصيد', numeric: true, minWidth: 120),
          ],
          // Row 0 is the opening balance line.
          onRowTap: onOpenReference == null
              ? null
              : (i) {
                  if (i > 0) onOpenReference!(statement.rows[i - 1].entry);
                },
          rows: [
            [
              const Text(''),
              const Text('رصيد أول المدة', style: TextStyle(fontWeight: FontWeight.w600)),
              const Text(''),
              const Text(''),
              const Text(''),
              MoneyText(statement.opening, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
            for (final r in statement.rows)
              [
                Text(Dates.format(r.entry.date)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.entry.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                    if (r.entry.typeLabel != null)
                      Text(r.entry.typeLabel!, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
                Text(r.entry.reference ?? ''),
                r.entry.increase == 0 ? const Text('') : MoneyText(r.entry.increase, tone: increaseTone),
                r.entry.decrease == 0 ? const Text('') : MoneyText(r.entry.decrease, tone: decreaseTone),
                MoneyText(r.balance, style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
          ],
          footer: [
            const Text(''),
            const Text('الإجمالي'),
            const Text(''),
            MoneyText(statement.totalIncrease),
            MoneyText(statement.totalDecrease),
            MoneyText(statement.closing),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [summary, const SizedBox(height: 12), body],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.label, this.amount, this.tone);
  final String label;
  final int amount;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          MoneyText(amount, tone: tone, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _MobileRow extends StatelessWidget {
  const _MobileRow({required this.row, required this.increaseTone, required this.decreaseTone});
  final StatementRow row;
  final Tone increaseTone;
  final Tone decreaseTone;

  @override
  Widget build(BuildContext context) {
    final e = row.entry;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                Text('${Dates.format(e.date)}${e.reference == null ? '' : ' • ${e.reference}'}', style: t.bodySmall),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (e.increase != 0) MoneyText(e.increase, tone: increaseTone, signed: true),
              if (e.decrease != 0) MoneyText(-e.decrease, tone: decreaseTone),
              MoneyText(row.balance, style: t.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}
