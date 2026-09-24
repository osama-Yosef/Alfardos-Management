import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/money_text.dart';
import '../domain/activity.dart';

class ActivityTile extends StatelessWidget {
  const ActivityTile({super.key, required this.activity, this.dense = false});

  final Activity activity;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final a = activity;
    final t = Theme.of(context).textTheme;
    return ListTile(
      dense: dense,
      onTap: a.route == null ? null : () => context.push(a.route!),
      leading: CircleAvatar(
        radius: dense ? 17 : 20,
        backgroundColor: a.tone.soft,
        child: Icon(a.icon, size: dense ? 18 : 20, color: a.tone.color),
      ),
      title: Text(
        a.isReversal ? 'إلغاء: ${a.effective.label}' : a.effective.label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: a.isReversal ? AppColors.textSecondary : null,
        ),
      ),
      subtitle: Text(
        [
          if (a.partyName != null && a.partyName!.isNotEmpty) a.partyName!,
          if (a.number != null) a.number!,
          Dates.format(a.date),
        ].join(' • '),
        style: t.bodySmall,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: MoneyText(a.amount, tone: a.tone, style: t.titleSmall),
    );
  }
}
