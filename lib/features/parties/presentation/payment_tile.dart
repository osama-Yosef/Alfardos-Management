import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../../core/permissions/permissions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/money_text.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/application/auth_providers.dart';
import '../application/party_providers.dart';
import '../domain/payment.dart';

class PaymentTile extends ConsumerWidget {
  const PaymentTile({super.key, required this.payment, this.showParty = true});

  final Payment payment;
  final bool showParty;

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final reason = await AppDialog.cancelReason(
      context,
      title: 'إلغاء السند ${payment.number}',
      message: 'سيتم إنشاء قيد عكسي يعيد رصيد الخزنة و${payment.kind.singular}. لا يمكن التراجع عن الإلغاء.',
    );
    if (reason == null || !context.mounted) return;
    await runWithFeedback(
      context,
      () => ref.read(partyRepositoryProvider(payment.kind)).cancelPayment(payment, reason, ref.read(ledgerProvider)),
      success: 'تم إلغاء السند',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = payment;
    final t = Theme.of(context).textTheme;
    final canCancel = ref.watch(canProvider(Permission.cancelPayments)) && !p.cancelled;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: p.cancelled ? AppColors.neutralSoft : (p.kind.isCustomer ? AppColors.successSoft : AppColors.warningSoft),
        child: Icon(
          p.kind.isCustomer ? Symbols.call_received : Symbols.call_made,
          size: 20,
          color: p.cancelled ? AppColors.neutral : (p.kind.isCustomer ? AppColors.success : AppColors.warning),
        ),
      ),
      title: Row(
        children: [
          Flexible(child: Text(showParty ? p.partyName : p.number, overflow: TextOverflow.ellipsis)),
          if (p.cancelled) ...[const SizedBox(width: 8), const StatusBadge('ملغى')],
        ],
      ),
      subtitle: Text(
        [
          if (showParty) p.number,
          Dates.format(p.date),
          '${p.method.label} • ${p.cashboxName}',
          if (p.notes.isNotEmpty) p.notes,
        ].join(' • '),
        style: t.bodySmall,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MoneyText(
            p.amount,
            tone: p.cancelled ? Tone.neutral : (p.kind.isCustomer ? Tone.success : Tone.warning),
            style: t.titleSmall?.copyWith(decoration: p.cancelled ? TextDecoration.lineThrough : null),
          ),
          if (canCancel)
            PopupMenuButton<String>(
              tooltip: 'خيارات',
              onSelected: (_) => _cancel(context, ref),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'cancel', child: Text('إلغاء السند', style: TextStyle(color: AppColors.danger))),
              ],
            ),
        ],
      ),
    );
  }
}
