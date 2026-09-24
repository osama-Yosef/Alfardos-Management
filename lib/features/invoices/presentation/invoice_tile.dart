import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/module_colors.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/money_text.dart';
import '../../../core/widgets/status_badge.dart';
import '../domain/invoice.dart';

class InvoiceTile extends StatelessWidget {
  const InvoiceTile({super.key, required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final inv = invoice;
    return ListTile(
      onTap: () => context.push('${inv.kind.route}/${inv.id}'),
      leading: ModuleIcon(
        icon: inv.kind.isSale ? Symbols.receipt_long : Symbols.shopping_cart,
        color: inv.cancelled
            ? AppColors.neutral
            : (inv.kind.isSale ? ModuleColors.sales : ModuleColors.purchases),
        size: 40,
      ),
      title: Row(
        children: [
          Text(inv.number, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          StatusBadge.invoice(cancelled: inv.cancelled, payment: inv.paymentStatus),
        ],
      ),
      subtitle: Text('${inv.partyName} • ${Dates.format(inv.date)}', style: t.bodySmall),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          MoneyText(
            inv.total,
            style: t.titleSmall?.copyWith(
              decoration: inv.cancelled ? TextDecoration.lineThrough : null,
            ),
          ),
          if (!inv.cancelled && inv.remaining > 0)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('متبقي ', style: t.bodySmall),
                MoneyText(inv.remaining, tone: Tone.danger, style: t.bodySmall),
              ],
            ),
        ],
      ),
    );
  }
}
