import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../../core/money/money.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/fields.dart';
import '../../auth/application/auth_providers.dart';
import '../application/party_providers.dart';
import '../domain/party.dart';

/// Add / edit customer or supplier. Returns the party id on success.
Future<String?> showPartyForm(BuildContext context, PartyKind kind, {Party? party}) {
  return AppDialog.show<String>(
    context,
    title: party == null ? 'إضافة ${kind.singular}' : 'تعديل بيانات ${kind.singular}',
    child: _PartyForm(kind: kind, party: party),
  );
}

class _PartyForm extends ConsumerStatefulWidget {
  const _PartyForm({required this.kind, this.party});

  final PartyKind kind;
  final Party? party;

  @override
  ConsumerState<_PartyForm> createState() => _PartyFormState();
}

class _PartyFormState extends ConsumerState<_PartyForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.party?.name);
  late final _phone = TextEditingController(text: widget.party?.phone);
  late final _address = TextEditingController(text: widget.party?.address);
  late final _notes = TextEditingController(text: widget.party?.notes);
  final _opening = TextEditingController();
  DateTime _openingDate = DateTime.now();
  bool _saving = false;

  bool get _isNew => widget.party == null;

  @override
  void dispose() {
    for (final c in [_name, _phone, _address, _notes, _opening]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final repo = ref.read(partyRepositoryProvider(widget.kind));
    final user = ref.read(currentUserProvider)!;
    final input = PartyInput(
      name: _name.text,
      phone: _phone.text,
      address: _address.text,
      notes: _notes.text,
    );
    final id = await runWithFeedback<String>(
      context,
      () async {
        if (_isNew) {
          return repo.create(
            input,
            user: user,
            ledger: ref.read(ledgerProvider),
            openingBalance: Money.parse(_opening.text) ?? 0,
            openingDate: _openingDate,
          );
        }
        await repo.update(widget.party!, input, user);
        return widget.party!.id;
      },
      success: _isNew ? 'تمت إضافة ${widget.kind.singular}' : 'تم حفظ التعديلات',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (id != null) Navigator.pop(context, id);
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.kind;
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            label: 'اسم ال${kind.singular}',
            controller: _name,
            autofocus: true,
            prefixIcon: Symbols.person,
            validator: (v) => Validators.required(v, 'الاسم'),
          ),
          const SizedBox(height: 14),
          AppTextField(
            label: 'رقم الهاتف',
            controller: _phone,
            keyboardType: TextInputType.phone,
            prefixIcon: Symbols.call,
            validator: Validators.phone,
            textDirection: TextDirection.ltr,
          ),
          const SizedBox(height: 14),
          AppTextField(label: 'العنوان', controller: _address, prefixIcon: Symbols.location_on),
          const SizedBox(height: 14),
          AppTextField(label: 'ملاحظات', controller: _notes, maxLines: 2),
          if (_isNew) ...[
            const SizedBox(height: 18),
            AmountField(
              label: 'الرصيد الافتتاحي (اختياري)',
              controller: _opening,
              required: false,
              allowZero: true,
              allowNegative: true,
              helper: kind.isCustomer
                  ? 'موجب: مبلغ مستحق على العميل. سالب: رصيد دائن للعميل.'
                  : 'موجب: مبلغ مستحق للمورد. سالب: دفعة مقدمة للمورد.',
            ),
            const SizedBox(height: 14),
            DateField(label: 'تاريخ الرصيد الافتتاحي', value: _openingDate, onChanged: (d) => setState(() => _openingDate = d)),
          ],
          const SizedBox(height: 22),
          PrimaryButton(label: 'حفظ', icon: Symbols.save, onPressed: _save, loading: _saving, expand: true),
        ],
      ),
    );
  }
}
