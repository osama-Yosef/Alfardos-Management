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
import '../application/cashbox_providers.dart';
import '../domain/cashbox.dart';

Future<void> showCashboxForm(BuildContext context, {Cashbox? cashbox}) {
  return AppDialog.show(
    context,
    title: cashbox == null ? 'إضافة خزنة / حساب' : 'تعديل ${cashbox.name}',
    child: _CashboxForm(cashbox: cashbox),
  );
}

class _CashboxForm extends ConsumerStatefulWidget {
  const _CashboxForm({this.cashbox});
  final Cashbox? cashbox;

  @override
  ConsumerState<_CashboxForm> createState() => _CashboxFormState();
}

class _CashboxFormState extends ConsumerState<_CashboxForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.cashbox?.name);
  late final _notes = TextEditingController(text: widget.cashbox?.notes);
  final _opening = TextEditingController();
  late CashboxKind _kind = widget.cashbox?.kind ?? CashboxKind.cash;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    _opening.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final repo = ref.read(cashboxRepositoryProvider);
    final user = ref.read(currentUserProvider)!;
    final ok = await runWithFeedback(
      context,
      () async {
        if (widget.cashbox == null) {
          await repo.create(
            name: _name.text,
            kind: _kind,
            notes: _notes.text,
            openingBalance: Money.parse(_opening.text) ?? 0,
            user: user,
            ledger: ref.read(ledgerProvider),
          );
        } else {
          await repo.update(widget.cashbox!, name: _name.text, kind: _kind, notes: _notes.text, user: user);
        }
        return true;
      },
      success: 'تم الحفظ',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok == true) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            label: 'الاسم',
            controller: _name,
            autofocus: true,
            hint: 'مثال: الخزنة الرئيسية، حساب البنك الأهلي',
            validator: (v) => Validators.required(v, 'الاسم'),
          ),
          const SizedBox(height: 14),
          AppDropdown<CashboxKind>(
            label: 'النوع',
            items: CashboxKind.values,
            value: _kind,
            itemLabel: (k) => k.label,
            onChanged: (k) => setState(() => _kind = k ?? CashboxKind.cash),
          ),
          if (widget.cashbox == null) ...[
            const SizedBox(height: 14),
            AmountField(
              label: 'الرصيد الافتتاحي',
              controller: _opening,
              required: false,
              allowZero: true,
              helper: 'المبلغ الموجود فعلياً في الخزنة أو الحساب الآن.',
            ),
          ],
          const SizedBox(height: 14),
          AppTextField(label: 'ملاحظات', controller: _notes, maxLines: 2),
          const SizedBox(height: 20),
          PrimaryButton(label: 'حفظ', icon: Symbols.save, onPressed: _save, loading: _saving, expand: true),
        ],
      ),
    );
  }
}
