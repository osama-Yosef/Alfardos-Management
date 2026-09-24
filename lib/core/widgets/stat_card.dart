import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/module_colors.dart';
import 'money_text.dart';

/// KPI card: colored accent strip, icon, label, amount and an optional hint.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.icon,
    this.amount,
    this.value,
    this.tone = Tone.primary,
    this.color,
    this.hint,
    this.onTap,
    this.loading = false,
  });

  final String label;
  final IconData icon;

  /// Money amount (minor units). Use [value] for non-money numbers.
  final int? amount;
  final String? value;
  final Tone tone;

  /// Overrides the tone color (e.g. a section color from [ModuleColors]).
  final Color? color;
  final String? hint;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final accent = color ?? tone.color;
    final valueStyle = t.titleLarge?.copyWith(fontSize: 21, fontWeight: FontWeight.w700);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [accent.withValues(alpha: 0.06), Colors.white],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(height: 4, color: accent),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ModuleIcon(icon: icon, color: accent, size: 38, solid: true),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            label,
                            style: t.bodyMedium?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (loading)
                      Container(
                        height: 24,
                        width: 110,
                        decoration: BoxDecoration(
                          color: AppColors.neutralSoft,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      )
                    else
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: amount != null
                            ? MoneyText(amount!, style: valueStyle?.copyWith(color: AppColors.textPrimary))
                            : Text(value ?? '-', style: valueStyle),
                      ),
                    if (hint != null) ...[
                      const SizedBox(height: 4),
                      Text(hint!, style: t.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
