import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/money/money.dart';
import '../../../core/settings/company_settings.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/fields.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/responsive.dart';
import '../../auth/application/auth_providers.dart';
import '../../cashboxes/application/cashbox_providers.dart';
import '../../cashboxes/domain/cashbox.dart';
import '../application/settings_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _form = GlobalKey<FormState>();
  late CompanySettings _initial = ref.read(companySettingsProvider);
  late CompanySettings _s = _initial;
  late final _c = {
    'companyName': TextEditingController(text: _s.companyName),
    'phone': TextEditingController(text: _s.phone),
    'address': TextEditingController(text: _s.address),
    'taxNumber': TextEditingController(text: _s.taxNumber),
    'currencyCode': TextEditingController(text: _s.currencyCode),
    'currencySymbol': TextEditingController(text: _s.currencySymbol),
    'invoicePrefix': TextEditingController(text: _s.invoicePrefix),
    'purchasePrefix': TextEditingController(text: _s.purchasePrefix),
    'receiptPrefix': TextEditingController(text: _s.receiptPrefix),
    'paymentPrefix': TextEditingController(text: _s.paymentPrefix),
    'expensePrefix': TextEditingController(text: _s.expensePrefix),
    'transferPrefix': TextEditingController(text: _s.transferPrefix),
    'invoiceFooter': TextEditingController(text: _s.invoiceFooter),
    'lowCash': TextEditingController(text: _s.lowCashThreshold == 0 ? '' : Money.toInput(_s.lowCashThreshold)),
    'largeExpense': TextEditingController(text: _s.largeExpenseThreshold == 0 ? '' : Money.toInput(_s.largeExpenseThreshold)),
  };
  bool _saving = false;
  bool _uploading = false;

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _uploadLogo() async {
    final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['png', 'jpg', 'jpeg']);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.length > 2 * 1024 * 1024) {
      if (mounted) Toast.info(context, 'حجم الشعار يجب ألا يتجاوز 2 ميجابايت.');
      return;
    }
    setState(() => _uploading = true);
    final ext = (file.extension ?? 'png').toLowerCase() == 'png' ? 'png' : 'jpeg';
    final url = await runWithFeedback(
      // ignore: use_build_context_synchronously
      context,
      () => ref.read(settingsRepositoryProvider).uploadLogo(bytes, ext),
    );
    if (!mounted) return;
    setState(() {
      _uploading = false;
      if (url != null) _s = _s.copyWith(logoUrl: url);
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final next = _s.copyWith(
      companyName: _c['companyName']!.text.trim(),
      phone: _c['phone']!.text.trim(),
      address: _c['address']!.text.trim(),
      taxNumber: _c['taxNumber']!.text.trim(),
      currencyCode: _c['currencyCode']!.text.trim(),
      currencySymbol: _c['currencySymbol']!.text.trim(),
      invoicePrefix: _c['invoicePrefix']!.text.trim(),
      purchasePrefix: _c['purchasePrefix']!.text.trim(),
      receiptPrefix: _c['receiptPrefix']!.text.trim(),
      paymentPrefix: _c['paymentPrefix']!.text.trim(),
      expensePrefix: _c['expensePrefix']!.text.trim(),
      transferPrefix: _c['transferPrefix']!.text.trim(),
      invoiceFooter: _c['invoiceFooter']!.text.trim(),
      lowCashThreshold: Money.parse(_c['lowCash']!.text) ?? 0,
      largeExpenseThreshold: Money.parse(_c['largeExpense']!.text) ?? 0,
    );
    setState(() => _saving = true);
    final ok = await runWithFeedback(context, () async {
      await ref.read(settingsRepositoryProvider).save(_initial, next, ref.read(currentUserProvider)!);
      return true;
    }, success: 'تم حفظ الإعدادات');
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok == true) {
        _initial = next;
        _s = next;
      }
    });
  }

  Widget _field(String key, String label, {String? helper, bool required = false}) => AppTextField(
        label: label,
        controller: _c[key],
        helper: helper,
        validator: required ? (v) => Validators.required(v, label) : null,
      );

  @override
  Widget build(BuildContext context) {
    final boxes = ref.watch(activeCashboxesProvider);
    final company = FormSection(
      title: 'بيانات الشركة',
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: Colors.white,
              backgroundImage: _s.logoUrl != null
                  ? NetworkImage(_s.logoUrl!)
                  : const AssetImage('assets/branding/logo_mark.png') as ImageProvider,
            ),
            const SizedBox(width: 12),
            SecondaryButton(
              label: _uploading ? 'جاري الرفع...' : 'تغيير الشعار',
              icon: Symbols.upload,
              onPressed: _uploading ? null : _uploadLogo,
            ),
            if (_s.logoUrl != null)
              TextButton(onPressed: () => setState(() => _s = _s.copyWith(clearLogo: true)), child: const Text('إزالة')),
          ],
        ),
        _field('companyName', 'اسم الشركة', required: true),
        _field('phone', 'الهاتف'),
        _field('address', 'العنوان'),
        _field('taxNumber', 'الرقم الضريبي / السجل التجاري'),
      ],
    );
    final currency = FormSection(
      title: 'العملة والترقيم',
      children: [
        _pair(_field('currencySymbol', 'رمز العملة', required: true), _field('currencyCode', 'كود العملة', helper: 'مثال: EGP, SAR, USD')),
        AppDropdown<int>(
          label: 'عدد الخانات العشرية في العرض',
          items: const [0, 2],
          value: _s.decimals,
          itemLabel: (v) => v == 0 ? 'بدون كسور' : 'خانتان',
          onChanged: (v) => setState(() => _s = _s.copyWith(decimals: v)),
        ),
        _pair(_field('invoicePrefix', 'بادئة فواتير البيع'), _field('purchasePrefix', 'بادئة فواتير الشراء')),
        _pair(_field('receiptPrefix', 'بادئة سندات القبض'), _field('paymentPrefix', 'بادئة سندات الصرف')),
        _pair(_field('expensePrefix', 'بادئة المصروفات'), _field('transferPrefix', 'بادئة التحويلات')),
      ],
    );
    final rules = FormSection(
      title: 'قواعد العمل',
      children: [
        AppDropdown<Cashbox>(
          label: 'الخزنة الافتراضية',
          items: boxes,
          value: boxes.where((b) => b.id == _s.defaultCashboxId).firstOrNull,
          itemLabel: (b) => b.name,
          onChanged: (b) => setState(() => _s = _s.copyWith(defaultCashboxId: b?.id)),
        ),
        _switch('السماح بالسحب على المكشوف', 'السماح برصيد سالب للخزائن', _s.allowNegativeCash,
            (v) => _s = _s.copyWith(allowNegativeCash: v)),
        _switch('السماح بالبيع بدون مخزون كافٍ', 'يمكن أن يصبح رصيد المخزون سالباً', _s.allowNegativeStock,
            (v) => _s = _s.copyWith(allowNegativeStock: v)),
        _switch('السماح بتحصيل أكثر من مديونية العميل', 'يصبح للعميل رصيد دائن', _s.allowCustomerOverpayment,
            (v) => _s = _s.copyWith(allowCustomerOverpayment: v)),
        _switch('السماح بالدفع للمورد أكثر من المستحق', 'يُسجل كدفعة مقدمة', _s.allowSupplierOverpayment,
            (v) => _s = _s.copyWith(allowSupplierOverpayment: v)),
      ],
    );
    final alerts = FormSection(
      title: 'التنبيهات',
      children: [
        AmountField(label: 'تنبيه انخفاض رصيد الخزنة عن', controller: _c['lowCash']!, required: false, allowZero: true,
            helper: 'اتركه فارغاً لتعطيل التنبيه'),
        AmountField(label: 'تنبيه عند مصروف أكبر من أو يساوي', controller: _c['largeExpense']!, required: false,
            allowZero: true, helper: 'اتركه فارغاً لتعطيل التنبيه'),
      ],
    );
    final printing = FormSection(
      title: 'الفواتير والطباعة',
      children: [
        AppDropdown<PaperSize>(
          label: 'مقاس الطباعة',
          items: PaperSize.values,
          value: _s.paperSize,
          itemLabel: (p) => p.label,
          onChanged: (p) => setState(() => _s = _s.copyWith(paperSize: p)),
        ),
        _field('invoiceFooter', 'نص أسفل الفاتورة'),
        _switch('تفعيل الضريبة (قريباً)', 'حفظ الإعداد للاستخدام في وحدة الضرائب المستقبلية', _s.taxEnabled,
            (v) => _s = _s.copyWith(taxEnabled: v)),
      ],
    );

    final left = [company, const SizedBox(height: 16), currency];
    final right = [rules, const SizedBox(height: 16), alerts, const SizedBox(height: 16), printing];
    return PageScaffold(
      title: 'الإعدادات',
      actions: [PrimaryButton(label: 'حفظ الإعدادات', icon: Symbols.save, onPressed: _save, loading: _saving)],
      body: Form(
        key: _form,
        child: context.isDesktop
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Column(children: left)),
                  const SizedBox(width: 16),
                  Expanded(child: Column(children: right)),
                ],
              )
            : Column(children: [...left, const SizedBox(height: 16), ...right]),
      ),
    );
  }

  Widget _pair(Widget a, Widget b) => context.isMobile
      ? Column(children: [a, const SizedBox(height: 14), b])
      : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: a),
          const SizedBox(width: 12),
          Expanded(child: b),
        ]);

  Widget _switch(String title, String subtitle, bool value, void Function(bool) apply) => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title),
        subtitle: Text(subtitle),
        value: value,
        onChanged: (v) => setState(() => apply(v)),
      );
}
