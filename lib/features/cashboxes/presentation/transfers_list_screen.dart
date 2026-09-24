import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../../core/permissions/permissions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/live_query_list.dart';
import '../../../core/widgets/money_text.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/application/auth_providers.dart';
import '../application/cashbox_providers.dart';
import '../domain/cashbox.dart';

class TransfersListScreen extends ConsumerWidget {
  const TransfersListScreen({super.key});

  Future<void> _cancel(BuildContext context, WidgetRef ref, Transfer t) async {
    final reason = await AppDialog.cancelReason(
      context,
      title: 'إلغاء التحويل ${t.number}',
      message: 'سيُسجل تحويل عكسي يعيد المبلغ إلى "${t.fromName}".',
    );
    if (reason == null || !context.mounted) return;
    await runWithFeedback(
      context,
      () => ref.read(cashboxRepositoryProvider).cancelTransfer(t, reason, ref.read(ledgerProvider)),
      success: 'تم إلغاء التحويل',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canCreate = ref.watch(canProvider(Permission.createTransfer));
    final canCancel = ref.watch(canProvider(Permission.cancelPayments));
    return PageScaffold(
      title: 'التحويلات بين الخزائن',
      actions: [
        if (canCreate)
          FilledButton.icon(
            onPressed: () => context.push('/transfers/new'),
            icon: const Icon(Symbols.swap_horiz),
            label: const Text('تحويل جديد'),
          ),
      ],
      body: LiveQueryList<Transfer>(
        query: ref.watch(cashboxRepositoryProvider).transfersQuery(),
        fromDoc: Transfer.fromDoc,
        empty: EmptyState(
          icon: Symbols.swap_horiz,
          title: 'لا توجد تحويلات',
          actionLabel: canCreate ? 'تحويل جديد' : null,
          onAction: () => context.push('/transfers/new'),
        ),
        itemBuilder: (context, t, _) => ListTile(
          leading: const CircleAvatar(
            backgroundColor: AppColors.infoSoft,
            child: Icon(Symbols.swap_horiz, color: AppColors.info, size: 20),
          ),
          title: Row(children: [
            Flexible(child: Text('${t.fromName}  ←  ${t.toName}', overflow: TextOverflow.ellipsis)),
            if (t.cancelled) ...[const SizedBox(width: 8), const StatusBadge('ملغى')],
          ]),
          subtitle: Text(
            [t.number, Dates.format(t.date), t.createdByName, if (t.notes.isNotEmpty) t.notes].join(' • '),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              MoneyText(
                t.amount,
                style: TextStyle(fontWeight: FontWeight.w600, decoration: t.cancelled ? TextDecoration.lineThrough : null),
              ),
              if (canCancel && !t.cancelled)
                PopupMenuButton<String>(
                  onSelected: (_) => _cancel(context, ref, t),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'cancel', child: Text('إلغاء التحويل', style: TextStyle(color: AppColors.danger))),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
