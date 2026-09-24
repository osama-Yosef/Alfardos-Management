import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/firebase/collections.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/fields.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../settings/application/settings_providers.dart';
import '../application/cashbox_providers.dart';
import '../domain/cashbox.dart';
import 'cashbox_dropdown.dart';

/// Moves money between cashboxes. Not revenue, expense or profit.
class TransferFormScreen extends ConsumerStatefulWidget {
  const TransferFormScreen({super.key, this.fromId});

  final String? fromId;

  @override
  ConsumerState<TransferFormScreen> createState() => _TransferFormScreenState();
}

class _TransferFormScreenState extends ConsumerState<TransferFormScreen> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _notes = TextEditingController();
  late final String _postingId = ref.read(firestoreProvider).collection(Col.financialTransactions).doc().id;
  Cashbox? _from;
  Cashbox? _to;
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final outcome = await runWithFeedback(
      context,
      () => ref.read(cashboxRepositoryProvider).transfer(
            postingId: _postingId,
            from: _from!,
            to: _to!,
            amount: Money.parse(_amount.text)!,
            date: Dates.withCurrentTime(_date),
            notes: _notes.text,
            ledger: ref.read(ledgerProvider),
          ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (outcome != null) {
      Toast.success(context, 'تم التحويل ${outcome.number}');
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final boxes = ref.watch(activeCashboxesProvider);
    if (_from == null && boxes.isNotEmpty) {
      _from = boxes.where((b) => b.id == widget.fromId).firstOrNull ?? ref.watch(defaultCashboxProvider);
    }
    // Keep the selected objects fresh (balances change live).
    _from = boxes.where((b) => b.id == _from?.id).firstOrNull ?? _from;
    _to = boxes.where((b) => b.id == _to?.id).firstOrNull;
    final allowOverdraft = ref.watch(companySettingsProvider).allowNegativeCash;

    return PageScaffold(
      title: 'تحويل بين الخزائن',
      maxWidth: 640,
      body: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FormSection(
              title: 'بيانات التحويل',
              children: [
                CashboxDropdown(label: 'من خزنة', value: _from, exclude: _to?.id, onChanged: (c) => setState(() => _from = c)),
                const Center(child: Icon(Symbols.arrow_downward, color: AppColors.primary)),
                CashboxDropdown(label: 'إلى خزنة', value: _to, exclude: _from?.id, onChanged: (c) => setState(() => _to = c)),
                AmountField(
                  label: 'المبلغ',
                  controller: _amount,
                  max: allowOverdraft || _from == null ? null : _from!.balance,
                  maxMessage: 'المبلغ أكبر من رصيد الخزنة المحول منها.',
                ),
                DateField(label: 'التاريخ', value: _date, onChanged: (d) => setState(() => _date = d)),
                AppTextField(label: 'ملاحظات', controller: _notes, maxLines: 2),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'التحويل ينقل المال بين الخزائن فقط، ولا يُحتسب إيراداً أو مصروفاً أو ربحاً.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            PrimaryButton(label: 'تنفيذ التحويل', icon: Symbols.swap_horiz, onPressed: _save, loading: _saving, expand: true),
          ],
        ),
      ),
    );
  }
}
