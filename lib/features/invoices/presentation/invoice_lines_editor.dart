import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/accounting/invoice_calculator.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/money_text.dart';
import '../../../core/widgets/responsive.dart';
import '../application/invoice_form_controller.dart';
import '../domain/invoice.dart';
import 'item_search_dialog.dart';

class InvoiceLinesEditor extends ConsumerWidget {
  const InvoiceLinesEditor({super.key, required this.kind});

  final InvoiceKind kind;

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final item = await showItemSearch(context, includeServices: kind.isSale);
    if (item != null) ref.read(invoiceFormProvider(kind).notifier).addItem(item);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(invoiceFormProvider(kind).select((s) => s.lines));
    return AppCard(
      title: 'الأصناف',
      subtitle: lines.isEmpty ? null : '${lines.length} صنف',
      trailing: lines.isEmpty
          ? null
          : SecondaryButton(label: 'إضافة صنف', icon: Symbols.add, onPressed: () => _add(context, ref)),
      child: lines.isEmpty
          ? InkWell(
              onTap: () => _add(context, ref),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 36),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                  color: AppColors.surfaceAlt,
                ),
                child: Column(
                  children: [
                    const Icon(Symbols.add_shopping_cart, size: 36, color: AppColors.primary),
                    const SizedBox(height: 8),
                    Text(kind.isSale ? 'اضغط لإضافة منتج أو خدمة' : 'اضغط لإضافة منتج',
                        style: Theme.of(context).textTheme.titleSmall),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                if (!context.isMobile) const _HeaderRow(),
                for (final line in lines) _LineRow(key: ValueKey(line.key), kind: kind, line: line),
              ],
            ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 12.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600);
    return const Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text('الصنف', style: style)),
          SizedBox(width: 8),
          SizedBox(width: 90, child: Text('الكمية', style: style)),
          SizedBox(width: 8),
          SizedBox(width: 120, child: Text('السعر', style: style)),
          SizedBox(width: 8),
          SizedBox(width: 110, child: Text('الإجمالي', style: style, textAlign: TextAlign.end)),
          SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _LineRow extends ConsumerStatefulWidget {
  const _LineRow({super.key, required this.kind, required this.line});

  final InvoiceKind kind;
  final DraftLine line;

  @override
  ConsumerState<_LineRow> createState() => _LineRowState();
}

class _LineRowState extends ConsumerState<_LineRow> {
  late final _qty = TextEditingController(text: formatQuantity(widget.line.quantity));
  late final _price = TextEditingController(text: Money.toInput(widget.line.unitPrice));

  @override
  void didUpdateWidget(covariant _LineRow old) {
    super.didUpdateWidget(old);
    // Quantity can change from outside (same item added twice).
    final q = Validators.parseQuantity(_qty.text);
    if (q != widget.line.quantity) _qty.text = formatQuantity(widget.line.quantity);
  }

  @override
  void dispose() {
    _qty.dispose();
    _price.dispose();
    super.dispose();
  }

  InvoiceFormController get _ctrl => ref.read(invoiceFormProvider(widget.kind).notifier);

  @override
  Widget build(BuildContext context) {
    final line = widget.line;
    final isService = line.item.kind == LineKind.service;
    final stock = line.item.stockQty;
    final lowStock = widget.kind.isSale && !isService && stock != null && stock < line.quantity;
    final t = Theme.of(context).textTheme;

    final qtyField = _NumberCell(
      controller: _qty,
      label: 'الكمية',
      error: Validators.quantity(_qty.text) != null,
      onChanged: (v) {
        final q = Validators.parseQuantity(v);
        if (q != null && q > 0) _ctrl.updateLine(line.key, quantity: q);
        setState(() {});
      },
    );
    final priceField = _NumberCell(
      controller: _price,
      label: widget.kind.priceLabel,
      error: Money.parse(_price.text) == null || Money.parse(_price.text)! < 0,
      onChanged: (v) {
        final p = Money.parse(v);
        if (p != null && p >= 0) _ctrl.updateLine(line.key, unitPrice: p);
        setState(() {});
      },
    );
    final total = MoneyText(Money.multiply(line.quantity, line.unitPrice), style: t.titleSmall);
    final remove = IconButton(
      tooltip: 'حذف',
      icon: const Icon(Symbols.delete, color: AppColors.danger, size: 20),
      onPressed: () => _ctrl.removeLine(line.key),
    );
    final name = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(line.item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(
          isService
              ? 'خدمة'
              : stock == null
                  ? (line.item.isManufactured ? 'منتج تصنيعي - يُخصم من مكوناته' : 'منتج')
                  : 'المتوفر: ${formatQuantity(stock)} ${line.item.unit}${lowStock ? ' - الكمية غير كافية' : ''}',
          style: t.bodySmall?.copyWith(color: lowStock ? AppColors.warning : null),
        ),
      ],
    );

    if (context.isMobile) {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Row(children: [Expanded(child: name), remove]),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: qtyField),
                const SizedBox(width: 8),
                Expanded(child: priceField),
                const SizedBox(width: 8),
                total,
              ],
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(flex: 4, child: name),
          const SizedBox(width: 8),
          SizedBox(width: 90, child: qtyField),
          const SizedBox(width: 8),
          SizedBox(width: 120, child: priceField),
          const SizedBox(width: 8),
          SizedBox(width: 110, child: Align(alignment: AlignmentDirectional.centerEnd, child: total)),
          SizedBox(width: 40, child: remove),
        ],
      ),
    );
  }
}

class _NumberCell extends StatelessWidget {
  const _NumberCell({required this.controller, required this.label, required this.onChanged, this.error = false});

  final TextEditingController controller;
  final String label;
  final ValueChanged<String> onChanged;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textDirection: TextDirection.ltr,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩۰-۹.,٫]'))],
      decoration: InputDecoration(
        labelText: context.isMobile ? label : null,
        isDense: true,
        errorText: error ? '' : null,
        errorStyle: const TextStyle(height: 0, fontSize: 0),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
    );
  }
}
