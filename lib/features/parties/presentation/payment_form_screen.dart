import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/firebase/collections.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/money/money.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/fields.dart';
import '../../../core/widgets/money_text.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../cashboxes/application/cashbox_providers.dart';
import '../../cashboxes/domain/cashbox.dart';
import '../../cashboxes/presentation/cashbox_dropdown.dart';
import '../../settings/application/settings_providers.dart';
import '../application/party_providers.dart';
import '../domain/party.dart';
import '../domain/payment.dart';
import 'party_picker.dart';

/// Customer receipt / supplier payment.
///
/// On save: party balance decreases, cashbox changes, a financial
/// transaction + sub-ledger records + audit log are written atomically.
class PaymentFormScreen extends ConsumerStatefulWidget {
  const PaymentFormScreen({super.key, required this.kind, this.partyId});

  final PartyKind kind;
  final String? partyId;

  @override
  ConsumerState<PaymentFormScreen> createState() => _PaymentFormScreenState();
}

class _PaymentFormScreenState extends ConsumerState<PaymentFormScreen> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _notes = TextEditingController();
  // Stable id for this submission: retrying never double-posts.
  late final String _postingId =
      ref.read(firestoreProvider).collection(Col.financialTransactions).doc().id;
  Party? _party;
  Cashbox? _cashbox;
  DateTime _date = DateTime.now();
  PaymentMethod _method = PaymentMethod.cash;
  bool _saving = false;
  bool _partyError = false;

  @override
  void initState() {
    super.initState();
    if (widget.partyId != null) {
      ref.read(partyRepositoryProvider(widget.kind)).watch(widget.partyId!).first.then((p) {
        if (mounted) setState(() => _party = p);
      });
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _partyError = _party == null);
    if (!_form.currentState!.validate() || _party == null) return;
    setState(() => _saving = true);
    final outcome = await runWithFeedback(
      context,
      () => ref.read(partyRepositoryProvider(widget.kind)).recordPayment(
            postingId: _postingId,
            party: _party!,
            cashboxId: _cashbox!.id,
            cashboxName: _cashbox!.name,
            amount: Money.parse(_amount.text)!,
            date: Dates.withCurrentTime(_date),
            method: _method,
            notes: _notes.text,
            ledger: ref.read(ledgerProvider),
          ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (outcome != null) {
      Toast.success(context, 'تم حفظ السند ${outcome.number}');
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.kind;
    final settings = ref.watch(companySettingsProvider);
    final allowOver = kind.isCustomer ? settings.allowCustomerOverpayment : settings.allowSupplierOverpayment;
    final balance = _party?.balance ?? 0;
    _cashbox ??= ref.watch(defaultCashboxProvider);

    return PageScaffold(
      title: kind.paymentTitle,
      maxWidth: 640,
      body: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FormSection(
              title: 'بيانات السند',
              children: [
                PartyPickerField(
                  kind: kind,
                  value: _party,
                  errorText: _partyError ? 'اختر ${kind.singular}.' : null,
                  onChanged: (p) => setState(() {
                    _party = p;
                    _partyError = false;
                  }),
                ),
                if (_party != null)
                  AppCard(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(child: Text(kind.balanceLabel)),
                        MoneyText(balance, style: const TextStyle(fontWeight: FontWeight.w700)),
                        if (balance > 0) ...[
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () => setState(() => _amount.text = Money.toInput(balance)),
                            child: const Text('سداد كامل'),
                          ),
                        ],
                      ],
                    ),
                  ),
                AmountField(
                  label: 'المبلغ',
                  controller: _amount,
                  autofocus: widget.partyId != null,
                  max: allowOver || _party == null ? null : balance,
                  maxMessage: kind.isCustomer
                      ? 'المبلغ أكبر من المستحق على العميل.'
                      : 'المبلغ أكبر من المستحق للمورد.',
                ),
                CashboxDropdown(value: _cashbox, onChanged: (c) => setState(() => _cashbox = c)),
                AppDropdown<PaymentMethod>(
                  label: 'طريقة الدفع',
                  items: PaymentMethod.values,
                  value: _method,
                  itemLabel: (m) => m.label,
                  prefixIcon: Symbols.credit_card,
                  onChanged: (m) => setState(() => _method = m ?? PaymentMethod.cash),
                ),
                DateField(label: 'التاريخ', value: _date, onChanged: (d) => setState(() => _date = d)),
                AppTextField(label: 'ملاحظات', controller: _notes, maxLines: 2),
              ],
            ),
            const SizedBox(height: 16),
            PrimaryButton(label: 'حفظ السند', icon: Symbols.check, onPressed: _save, loading: _saving, expand: true),
          ],
        ),
      ),
    );
  }
}
