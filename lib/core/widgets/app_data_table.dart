import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AppColumn {
  const AppColumn(this.label, {this.numeric = false, this.flex = 1, this.minWidth = 110});

  final String label;
  final bool numeric;
  final int flex;
  final double minWidth;
}

/// Lightweight data table: styled header, zebra-free rows with dividers,
/// row tap, and horizontal scrolling when the columns do not fit.
class AppDataTable extends StatelessWidget {
  const AppDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.onRowTap,
    this.footer,
  });

  final List<AppColumn> columns;
  final List<List<Widget>> rows;
  final void Function(int index)? onRowTap;
  final List<Widget>? footer;

  @override
  Widget build(BuildContext context) {
    final minWidth = columns.fold<double>(0, (s, c) => s + c.minWidth) + 32;
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth.isFinite && constraints.maxWidth > minWidth
          ? constraints.maxWidth
          : minWidth;
      final table = SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              color: AppColors.surfaceAlt,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: _row(
                [
                  for (final c in columns)
                    Text(c.label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        )),
                ],
              ),
            ),
            for (var i = 0; i < rows.length; i++) ...[
              const Divider(),
              InkWell(
                onTap: onRowTap == null ? null : () => onRowTap!(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: DefaultTextStyle.merge(
                    style: const TextStyle(fontSize: 14),
                    child: _row(rows[i]),
                  ),
                ),
              ),
            ],
            if (footer != null) ...[
              const Divider(),
              Container(
                color: AppColors.surfaceAlt,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: DefaultTextStyle.merge(
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  child: _row(footer!),
                ),
              ),
            ],
          ],
        ),
      );
      if (width <= constraints.maxWidth) return table;
      return SingleChildScrollView(scrollDirection: Axis.horizontal, child: table);
    });
  }

  Widget _row(List<Widget> cells) {
    return Row(
      children: [
        for (var i = 0; i < columns.length; i++)
          Expanded(
            flex: columns[i].flex,
            child: Align(
              alignment: columns[i].numeric
                  ? AlignmentDirectional.centerEnd
                  : AlignmentDirectional.centerStart,
              child: i < cells.length ? cells[i] : const SizedBox.shrink(),
            ),
          ),
      ],
    );
  }
}
