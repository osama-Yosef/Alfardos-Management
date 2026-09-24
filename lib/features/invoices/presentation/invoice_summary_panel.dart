import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/money/money.dart';
import '../../../core/permissions/permissions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/fields.dart';
import '../../../core/widgets/money_text.dart';
import '../../auth/application/auth_providers.dart';
import '../../cashboxes/presentation/cashbox_dropdown.dart';
import '../../parties/domain/payment.dart';
import '../application/invoice_form_controller.dart';
import '../domain/invoice.dart';

/// Totals, discount and payment section of the invoice form.
class InvoiceSummaryPanel extends ConsumerStatefulWidget {
  const InvoiceSummaryPanel({super.key, required this.kind});

  final InvoiceKind kind;

  @override
  ConsumerState<InvoiceSummaryPanel> createState() => _InvoiceSummaryPanelState();
}

class _InvoiceSummaryPanelState extends ConsumerState<InvoiceSummaryPanel> {
  final _discount = TextEditingController();
  final _paid = TextEditingController();
  final _notes = TextEditingController();

  @override
  void dispose() {
    _discount.dispose();
    _paid.dispose();
    _notes.dispose();
    super.dispose();
  }

  InvoiceFormController get _ctrl => ref.read(invoiceFormProvider(widget.kind).notifier);

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(invoiceFormProvider(widget.kind));
    final showCost = widget.kind.isSale && ref.watch(canProvider(Permission.viewCost));
    final preview = s.preview;
    final t = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          title: 'الإجمالي',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InfoRow(label: 'المجموع', value: MoneyText(s.subtotal)),
              const SizedBox(height: 6),
              AmountField(
                label: 'الخصم',
                controller: _discount,
                required: false,
                allowZero: true,
                max: s.subtotal,
                maxMessage: 'الخصم أكبر من المجموع.',
                onChanged: (v) => _ctrl.setDiscount(Money.parse(v) ?? 0),
              ),
              const SizedBox(height: 8),
              const Divider(),
              InfoRow(label: 'الصافي', emphasize: true, value: MoneyText(s.total, style: t.titleLarge)),
              if (showCost && preview != null) ...[
                InfoRow(label: 'التكلفة التقديرية', value: MoneyText(preview.totalCost)),
                InfoRow(
                  label: 'الربح التقديري',
                  value: MoneyText(preview.grossProfit, autoTone: true),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          title: 'الدفع',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<PaymentMode>(
                showSelectedIcon: false,
                segments: [
                  for (final m in PaymentMode.values)
                    ButtonSegment(
                      value: m,
                      enabled: m == PaymentMode.full || s.party != null,
                      label: Text(switch (m) {
                        PaymentMode.full => 'نقدي',
                        PaymentMode.partial => 'جزئي',
                        PaymentMode.credit => 'آجل',
                      }),
                    ),
                ],
                selected: {s.mode},
                onSelectionChanged: (v) => _ctrl.setMode(v.first),
              ),
              if (s.party == null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('البيع أو الشراء الآجل يتطلب اختيار ${widget.kind.partyLabel}.', style: t.bodySmall),
                ),
              if (s.mode == PaymentMode.partial) ...[
                const SizedBox(height: 12),
                AmountField(
                  label: 'المبلغ المدفوع',
                  controller: _paid,
                  max: s.total,
                  maxMessage: 'المدفوع أكبر من الصافي.',
                  onChanged: (v) => _ctrl.setPartialPaid(Money.parse(v) ?? 0),
                ),
              ],
              if (s.paid > 0) ...[
                const SizedBox(height: 12),
                CashboxDropdown(value: s.cashbox, onChanged: _ctrl.setCashbox),
                const SizedBox(height: 12),
                AppDropdown<PaymentMethod>(
                  label: 'طريقة الدفع',
                  items: PaymentMethod.values,
                  value: s.method,
                  itemLabel: (m) => m.label,
                  onChanged: (m) => _ctrl.setMethod(m ?? PaymentMethod.cash),
                ),
              ],
              const SizedBox(height: 10),
              InfoRow(label: 'المدفوع', value: MoneyText(s.paid, tone: Tone.success)),
              InfoRow(
                label: 'المتبقي',
                value: MoneyText(s.remaining, tone: s.remaining > 0 ? Tone.danger : Tone.neutral),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          title: 'تفاصيل إضافية',
          child: Column(
            children: [
              DateField(label: 'تاريخ الفاتورة', value: s.date, onChanged: _ctrl.setDate),
              const SizedBox(height: 12),
              AppTextField(label: 'ملاحظات', controller: _notes, maxLines: 2, onChanged: _ctrl.setNotes),
            ],
          ),
        ),
        if (s.remaining > 0 && s.party != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                const Icon(Symbols.info, size: 18, color: AppColors.warning),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.kind.isSale
                        ? 'سيُضاف المتبقي إلى رصيد العميل ${s.party!.name}.'
                        : 'سيُضاف المتبقي إلى المستحق للمورد ${s.party!.name}.',
                    style: t.bodySmall,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
