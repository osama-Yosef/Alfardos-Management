import 'package:flutter/material.dart';

import '../accounting/invoice_calculator.dart';
import '../theme/app_colors.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.label, {super.key, this.tone = Tone.neutral, this.icon});

  final String label;
  final Tone tone;
  final IconData? icon;

  /// Badge for an invoice document considering cancellation and payment.
  factory StatusBadge.invoice({required bool cancelled, required PaymentStatus payment}) {
    if (cancelled) return const StatusBadge('ملغاة', tone: Tone.neutral);
    return switch (payment) {
      PaymentStatus.paid => const StatusBadge('مدفوعة', tone: Tone.success),
      PaymentStatus.partial => const StatusBadge('مدفوعة جزئياً', tone: Tone.warning),
      PaymentStatus.unpaid => const StatusBadge('آجلة', tone: Tone.danger),
    };
  }

  factory StatusBadge.active(bool active) => active
      ? const StatusBadge('نشط', tone: Tone.success)
      : const StatusBadge('موقوف', tone: Tone.neutral);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: tone.soft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: tone.color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: tone.color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
