import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/permissions/permissions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/money_text.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/application/auth_providers.dart';
import '../application/cashbox_providers.dart';
import '../domain/cashbox.dart';
import 'cashbox_form.dart';

class CashboxListScreen extends ConsumerWidget {
  const CashboxListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boxes = ref.watch(cashboxesProvider);
    final canManage = ref.watch(canProvider(Permission.manageCashboxes));
    final canTransfer = ref.watch(canProvider(Permission.createTransfer));
    final total = ref.watch(totalCashProvider);

    return PageScaffold(
      title: 'الخزائن والحسابات',
      actions: [
        if (canTransfer)
          OutlinedButton.icon(
            onPressed: () => context.push('/transfers/new'),
            icon: const Icon(Symbols.swap_horiz),
            label: const Text('تحويل'),
          ),
        if (canManage)
          FilledButton.icon(
            onPressed: () => showCashboxForm(context),
            icon: const Icon(Symbols.add),
            label: Text(context.isMobile ? 'إضافة' : 'إضافة خزنة'),
          ),
      ],
      body: AsyncView(
        value: boxes,
        data: (list) {
          if (list.isEmpty) {
            return Card(
              child: EmptyState(
                icon: Symbols.account_balance_wallet,
                title: 'لا توجد خزائن',
                message: 'أضف خزنة نقدية أو حساباً بنكياً لتسجيل المقبوضات والمدفوعات.',
                actionLabel: canManage ? 'إضافة خزنة' : null,
                onAction: () => showCashboxForm(context),
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StatCard(
                label: 'إجمالي الأرصدة في جميع الخزائن',
                icon: Symbols.account_balance,
                amount: total,
                tone: total < 0 ? Tone.danger : Tone.primary,
              ),
              const SizedBox(height: 16),
              ResponsiveGrid(
                minItemWidth: 280,
                maxColumns: 3,
                children: [for (final c in list) _CashboxCard(box: c, canManage: canManage)],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CashboxCard extends StatelessWidget {
  const _CashboxCard({required this.box, required this.canManage});

  final Cashbox box;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppCard(
      onTap: () => context.push('/cashboxes/${box.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primarySoft,
                child: Icon(box.kind.icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(box.name, style: t.titleSmall),
                    Text(box.kind.label, style: t.bodySmall),
                  ],
                ),
              ),
              if (!box.active) StatusBadge.active(false),
            ],
          ),
          const SizedBox(height: 16),
          Text('الرصيد الحالي', style: t.bodySmall),
          MoneyText(box.balance, style: t.headlineSmall, tone: box.balance < 0 ? Tone.danger : null),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Symbols.arrow_downward, size: 16, color: AppColors.success),
              const SizedBox(width: 4),
              MoneyText(box.totalIn, style: t.bodySmall, tone: Tone.success),
              const SizedBox(width: 16),
              const Icon(Symbols.arrow_upward, size: 16, color: AppColors.danger),
              const SizedBox(width: 4),
              MoneyText(box.totalOut, style: t.bodySmall, tone: Tone.danger),
            ],
          ),
        ],
      ),
    );
  }
}
