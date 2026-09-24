import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/firebase/collections.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/money/money.dart';
import '../../../core/permissions/permissions.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/fields.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../auth/application/auth_providers.dart';
import '../../cashboxes/application/cashbox_providers.dart';
import '../../cashboxes/domain/cashbox.dart';
import '../../cashboxes/presentation/cashbox_dropdown.dart';
import '../../settings/application/settings_providers.dart';
import '../application/expense_providers.dart';
import '../domain/expense.dart';

class ExpenseFormScreen extends ConsumerStatefulWidget {
  const ExpenseFormScreen({super.key});

  @override
  ConsumerState<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends ConsumerState<ExpenseFormScreen> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _description = TextEditingController();
  late final String _postingId = ref.read(firestoreProvider).collection(Col.financialTransactions).doc().id;
  ExpenseCategory? _category;
  Cashbox? _cashbox;
  DateTime _date = DateTime.now();
  ({Uint8List bytes, String ext, String name})? _attachment;
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      if (mounted) Toast.info(context, 'حجم الملف أكبر من 5 ميجابايت.');
      return;
    }
    final ext = (file.extension ?? 'jpg').toLowerCase().replaceAll('.', '');
    setState(() => _attachment = (bytes: bytes, ext: ext == 'jpg' ? 'jpeg' : ext, name: file.name));
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final repo = ref.read(expenseRepositoryProvider);
    final outcome = await runWithFeedback(context, () async {
      String? url;
      if (_attachment != null) {
        url = await repo.uploadAttachment(_postingId, _attachment!.bytes, _attachment!.ext);
      }
      return repo.create(
        postingId: _postingId,
        category: _category!,
        cashbox: _cashbox!,
        amount: Money.parse(_amount.text)!,
        date: Dates.withCurrentTime(_date),
        description: _description.text,
        attachmentUrl: url,
        ledger: ref.read(ledgerProvider),
      );
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (outcome != null) {
      Toast.success(context, 'تم تسجيل المصروف ${outcome.number}');
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(activeExpenseCategoriesProvider);
    final canManageCats = ref.watch(canProvider(Permission.manageExpenseCategories));
    final allowOverdraft = ref.watch(companySettingsProvider).allowNegativeCash;
    _cashbox ??= ref.watch(defaultCashboxProvider);
    final box = ref.watch(activeCashboxesProvider).where((b) => b.id == _cashbox?.id).firstOrNull ?? _cashbox;

    return PageScaffold(
      title: 'إضافة مصروف',
      maxWidth: 640,
      body: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FormSection(
              title: 'بيانات المصروف',
              trailing: canManageCats
                  ? TextButton(
                      onPressed: () => context.push('/expenses/categories'),
                      child: const Text('إدارة البنود'),
                    )
                  : null,
              children: [
                AppDropdown<ExpenseCategory>(
                  label: 'البند',
                  items: categories,
                  value: _category,
                  itemLabel: (c) => c.name,
                  prefixIcon: Symbols.category,
                  validator: (v) => v == null ? 'اختر بند المصروف.' : null,
                  onChanged: (c) => setState(() => _category = c),
                ),
                AmountField(
                  label: 'المبلغ',
                  controller: _amount,
                  max: allowOverdraft || box == null ? null : box.balance,
                  maxMessage: 'المبلغ أكبر من رصيد الخزنة.',
                ),
                CashboxDropdown(value: box, onChanged: (c) => setState(() => _cashbox = c)),
                DateField(label: 'التاريخ', value: _date, onChanged: (d) => setState(() => _date = d)),
                AppTextField(label: 'الوصف', controller: _description, maxLines: 2),
                OutlinedButton.icon(
                  onPressed: _pickAttachment,
                  icon: Icon(_attachment == null ? Symbols.attach_file : Symbols.check_circle),
                  label: Text(_attachment == null ? 'إرفاق إيصال (صورة أو PDF)' : _attachment!.name),
                ),
              ],
            ),
            const SizedBox(height: 16),
            PrimaryButton(label: 'حفظ المصروف', icon: Symbols.check, onPressed: _save, loading: _saving, expand: true),
          ],
        ),
      ),
    );
  }
}
