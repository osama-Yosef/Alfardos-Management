import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../utils/dates.dart';

/// A selected period: a preset or a custom range.
class Period {
  const Period(this.preset, this.range);

  factory Period.of(PeriodPreset preset) => Period(preset, preset.range());

  final PeriodPreset preset;
  final DateRange range;

  String get label => preset == PeriodPreset.custom ? range.label : preset.label;

  @override
  bool operator ==(Object other) =>
      other is Period && other.preset == preset && other.range == range;

  @override
  int get hashCode => Object.hash(preset, range);
}

/// Horizontal chips: اليوم / هذا الأسبوع / ... / فترة مخصصة.
class PeriodSelector extends StatelessWidget {
  const PeriodSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.presets = PeriodPreset.values,
  });

  final Period value;
  final ValueChanged<Period> onChanged;
  final List<PeriodPreset> presets;

  Future<void> _pickCustom(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(start: value.range.from, end: value.range.to),
      saveText: 'تطبيق',
    );
    if (picked != null) {
      onChanged(Period(PeriodPreset.custom, DateRange(picked.start, picked.end)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final p in presets)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ChoiceChip(
                label: Text(p == PeriodPreset.custom && value.preset == PeriodPreset.custom
                    ? value.range.label
                    : p.label),
                avatar: p == PeriodPreset.custom ? const Icon(Symbols.date_range, size: 18) : null,
                selected: value.preset == p,
                showCheckmark: false,
                onSelected: (_) {
                  if (p == PeriodPreset.custom) {
                    _pickCustom(context);
                  } else {
                    onChanged(Period.of(p));
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}
