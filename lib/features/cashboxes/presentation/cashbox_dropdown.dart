import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../settings/application/settings_providers.dart';
import '../application/cashbox_providers.dart';
import '../domain/cashbox.dart';

/// Dropdown of active cashboxes showing their current balance.
class CashboxDropdown extends ConsumerWidget {
  const CashboxDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'الخزنة',
    this.exclude,
    this.enabled = true,
  });

  final Cashbox? value;
  final ValueChanged<Cashbox?> onChanged;
  final String label;
  final String? exclude;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = ref.watch(moneyFormatterProvider);
    final boxes = ref.watch(activeCashboxesProvider).where((c) => c.id != exclude).toList();
    final selected = boxes.where((c) => c.id == value?.id).firstOrNull;
    return DropdownButtonFormField<Cashbox>(
      key: ValueKey('${selected?.id}-${boxes.length}'),
      initialValue: selected,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Symbols.account_balance_wallet, size: 20),
      ),
      validator: (v) => v == null ? 'اختر الخزنة.' : null,
      items: [
        for (final c in boxes)
          DropdownMenuItem(
            value: c,
            child: Text('${c.name}  (${fmt(c.balance)})', overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: enabled ? onChanged : null,
    );
  }
}
