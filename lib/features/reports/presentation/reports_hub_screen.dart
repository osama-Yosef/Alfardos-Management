import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/permissions/permissions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/module_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/responsive.dart';
import '../../auth/application/auth_providers.dart';
import '../domain/report_type.dart';

class ReportsHubScreen extends ConsumerWidget {
  const ReportsHubScreen({super.key});

  static Color _colorOf(ReportType t) => switch (t) {
        ReportType.profit => ModuleColors.receipts,
        ReportType.sales => ModuleColors.sales,
        ReportType.purchases => ModuleColors.purchases,
        ReportType.expenses => ModuleColors.expenses,
        ReportType.customerDebts => ModuleColors.customers,
        ReportType.supplierPayables => ModuleColors.suppliers,
        ReportType.cashboxes => ModuleColors.cashboxes,
        ReportType.services => ModuleColors.services,
        ReportType.products => ModuleColors.products,
        ReportType.journal => ModuleColors.reports,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canCost = ref.watch(canProvider(Permission.viewCost));
    final types = ReportType.values.where((t) => canCost || !t.needsCost || t == ReportType.sales);
    final t = Theme.of(context).textTheme;
    return PageScaffold(
      title: 'التقارير',
      subtitle: 'كل التقارير محسوبة مباشرة من السجلات المالية الفعلية',
      body: ResponsiveGrid(
        minItemWidth: 280,
        maxColumns: 3,
        children: [
          for (final type in types)
            AppCard(
              onTap: () => context.push('/reports/${type.slug}'),
              child: Row(
                children: [
                  ModuleIcon(icon: type.icon, color: _colorOf(type), size: 46, solid: true),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(type.title, style: t.titleSmall),
                        const SizedBox(height: 2),
                        Text(type.description, style: t.bodySmall, maxLines: 2),
                      ],
                    ),
                  ),
                  const Icon(Symbols.chevron_left, color: AppColors.textMuted),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
