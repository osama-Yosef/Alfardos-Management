import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/fields.dart';
import '../../../core/widgets/money_text.dart';
import '../../auth/application/auth_providers.dart';
import '../application/party_providers.dart';
import '../domain/party.dart';
import 'party_form.dart';

/// Field showing the selected customer/supplier; tapping opens a search
/// dialog with quick "add new".
class PartyPickerField extends ConsumerWidget {
  const PartyPickerField({
    super.key,
    required this.kind,
    required this.value,
    required this.onChanged,
    this.noneLabel,
    this.errorText,
  });

  final PartyKind kind;
  final Party? value;
  final ValueChanged<Party?> onChanged;

  /// When set, the user may clear the selection (e.g. "عميل نقدي").
  final String? noneLabel;
  final String? errorText;

  Future<void> _open(BuildContext context) async {
    final result = await showDialog<Object>(
      context: context,
      builder: (_) => _PartySearchDialog(kind: kind, noneLabel: noneLabel),
    );
    if (result is Party) onChanged(result);
    if (result == _none) onChanged(null);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = kind.isCustomer ? 'العميل' : 'المورد';
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _open(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          errorText: errorText,
          prefixIcon: Icon(kind.isCustomer ? Symbols.person : Symbols.local_shipping, size: 20),
          suffixIcon: const Icon(Symbols.unfold_more, size: 20),
        ),
        child: value == null
            ? Text(noneLabel ?? 'اختر $label', style: const TextStyle(color: AppColors.textSecondary))
            : Row(
                children: [
                  Expanded(child: Text(value!.name, overflow: TextOverflow.ellipsis)),
                  if (value!.balance != 0) ...[
                    Text('الرصيد: ', style: Theme.of(context).textTheme.bodySmall),
                    MoneyText(value!.balance, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ],
              ),
      ),
    );
  }
}

const _none = Object();

class _PartySearchDialog extends ConsumerStatefulWidget {
  const _PartySearchDialog({required this.kind, this.noneLabel});

  final PartyKind kind;
  final String? noneLabel;

  @override
  ConsumerState<_PartySearchDialog> createState() => _PartySearchDialogState();
}

class _PartySearchDialogState extends ConsumerState<_PartySearchDialog> {
  List<Party>? _results;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _search('');
  }

  Future<void> _search(String q) async {
    _query = q;
    final list = await ref.read(partyRepositoryProvider(widget.kind)).search(q);
    if (mounted && _query == q) setState(() => _results = list);
  }

  Future<void> _addNew() async {
    final id = await showPartyForm(context, widget.kind);
    if (id == null || !mounted) return;
    final party = await ref.read(partyRepositoryProvider(widget.kind)).watch(id).first;
    if (mounted) Navigator.pop(context, party);
  }

  @override
  Widget build(BuildContext context) {
    final canAdd = ref.watch(canProvider(widget.kind.manage));
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: SizedBox(
        width: 520,
        height: 560,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('اختيار ${widget.kind.singular}', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              SearchField(onChanged: _search, autofocus: true, hint: 'ابحث بالاسم أو الهاتف...'),
              const SizedBox(height: 8),
              if (widget.noneLabel != null)
                ListTile(
                  leading: const Icon(Symbols.person_off),
                  title: Text(widget.noneLabel!),
                  onTap: () => Navigator.pop(context, _none),
                ),
              if (canAdd)
                ListTile(
                  leading: const Icon(Symbols.person_add, color: AppColors.primary),
                  title: Text('إضافة ${widget.kind.singular} جديد',
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                  onTap: _addNew,
                ),
              const Divider(),
              Expanded(
                child: _results == null
                    ? const Center(child: CircularProgressIndicator())
                    : _results!.isEmpty
                        ? const Center(child: Text('لا توجد نتائج'))
                        : ListView.builder(
                            itemCount: _results!.length,
                            itemBuilder: (context, i) {
                              final p = _results![i];
                              return ListTile(
                                title: Text(p.name),
                                subtitle: p.phone.isEmpty ? null : Text(p.phone),
                                trailing: MoneyText(p.balance, style: Theme.of(context).textTheme.bodySmall),
                                onTap: () => Navigator.pop(context, p),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
