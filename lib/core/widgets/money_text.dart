import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/application/settings_providers.dart';
import '../theme/app_colors.dart';

/// Displays a minor-unit amount formatted with the company currency.
///
/// [tone] colors the value; [autoTone] colors positive green / negative red.
class MoneyText extends ConsumerWidget {
  const MoneyText(
    this.amount, {
    super.key,
    this.style,
    this.tone,
    this.autoTone = false,
    this.signed = false,
    this.compact = false,
  });

  final int amount;
  final TextStyle? style;
  final Tone? tone;
  final bool autoTone;
  final bool signed;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = ref.watch(moneyFormatterProvider);
    final effectiveTone = tone ??
        (autoTone ? (amount > 0 ? Tone.success : (amount < 0 ? Tone.danger : Tone.neutral)) : null);
    final text = compact ? fmt.compact(amount) : fmt(amount, signed: signed);
    return Text(
      text,
      textDirection: TextDirection.ltr,
      style: (style ?? DefaultTextStyle.of(context).style).copyWith(
        color: effectiveTone?.color,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
