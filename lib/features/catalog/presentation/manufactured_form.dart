import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/accounting/recipe.dart';
import '../../../core/money/money.dart';
import '../../../core/permissions/permissions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/fields.dart';
import '../../../core/widgets/money_text.dart';
import '../../../core/widgets/responsive.dart';
import '../../auth/application/auth_providers.dart';
import '../../invoices/presentation/item_search_dialog.dart';
import '../../settings/application/settings_providers.dart';
import '../application/catalog_providers.dart';
import '../data/catalog_repository.dart';
import '../domain/catalog_item.dart';

Future<void> showManufacturedForm(BuildContext context, {Product? product}) {
  return AppDialog.show(
    context,
    title: product == null ? 'إضافة منتج تصنيعي' : 'تعديل ${product.name}',
    maxWidth: 640,
    child: _ManufacturedForm(product: product),
  );
}

/// One component row being edited.
class _Row {
  _Row({required this.productId, required this.name, required this.unit, required this.unitCost, double? quantity})
      : qty = TextEditingController(text: quantity == null ? '1' : formatQuantity(quantity));

  final String productId;
  final String name;
  final String unit;
  final int unitCost;
  final TextEditingController qty;

  double? get quantity => Validators.parseQuantity(qty.text);
  int get cost => Money.multiply(quantity ?? 0, unitCost);
}

class _ManufacturedForm extends ConsumerStatefulWidget {
  const _ManufacturedForm({this.product});
  final Product? product;

  @override
  ConsumerState<_ManufacturedForm> createState() => _ManufacturedFormState();
}

class _ManufacturedFormState extends ConsumerState<_ManufacturedForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.product?.name);
  late final _sku = TextEditingController(text: widget.product?.sku);
  late final _barcode = TextEditingController(text: widget.product?.barcode);
  late final _unit = TextEditingController(text: widget.product?.unit ?? 'قطعة');
  late final _price = TextEditingController(text: widget.product == null ? '' : Money.toInput(widget.product!.sellPrice));
  late final _description = TextEditingController(text: widget.product?.description);
  final _rows = <_Row>[];
  bool _loading = false;
  bool _saving = false;

  bool get _isNew => widget.product == null;
  int get _cost => _rows.fold(0, (s, r) => s + r.cost);

  @override
  void initState() {
    super.initState();
    if (!_isNew) _loadComponents();
  }

  /// Loads the current name, unit and average cost of every component.
  Future<void> _loadComponents() async {
    setState(() => _loading = true);
    final recipe = widget.product!.components;
    final products = await ref.read(catalogRepositoryProvider).productsByIds(recipe.map((c) => c.productId));
    final byId = {for (final p in products) p.id: p};
    if (!mounted) return;
    setState(() {
      for (final c in recipe) {
        final p = byId[c.productId];
        _rows.add(_Row(
          productId: c.productId,
          name: p?.name ?? c.name,
          unit: p?.unit ?? '',
          unitCost: p?.costPrice ?? 0,
          quantity: c.quantity,
        ));
      }
      _loading = false;
    });
  }

  @override
  void dispose() {
    for (final c in [_name, _sku, _barcode, _unit, _price, _description]) {
      c.dispose();
    }
    for (final r in _rows) {
      r.qty.dispose();
    }
    super.dispose();
  }

  Future<void> _addComponent() async {
    final item = await showItemSearch(context, includeServices: false, title: 'إضافة مكوّن');
    if (item == null || !mounted) return;
    if (item.id == widget.product?.id || _rows.any((r) => r.productId == item.id)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('هذا المكوّن مضاف بالفعل.')));
      return;
    }
    setState(() => _rows.add(_Row(productId: item.id, name: item.name, unit: item.unit, unitCost: item.cost)));
  }

  void _removeComponent(_Row row) {
    setState(() => _rows.remove(row));
    row.qty.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_rows.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('أضف مكوّناً واحداً على الأقل من المنتجات.')));
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(catalogRepositoryProvider);
    final user = ref.read(currentUserProvider)!;
    final input = ManufacturedInput(
      name: _name.text,
      sku: _sku.text,
      barcode: _barcode.text,
      unit: _unit.text,
      sellPrice: Money.parse(_price.text) ?? 0,
      description: _description.text,
      estimatedCost: _cost,
      components: [
        for (final r in _rows) RecipeComponent(productId: r.productId, name: r.name, quantity: r.quantity!),
      ],
    );
    final ok = await runWithFeedback(context, () async {
      if (_isNew) {
        await repo.createManufactured(input, user);
      } else {
        await repo.updateManufactured(widget.product!, input, user);
      }
      return true;
    }, success: 'تم الحفظ');
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok == true) Navigator.pop(context);
  }

  Future<void> _toggleActive() async {
    final p = widget.product!;
    await runWithFeedback(
      context,
      () => ref.read(catalogRepositoryProvider).setProductActive(p, !p.active, ref.read(currentUserProvider)!),
      success: 'تم الحفظ',
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final canCost = ref.watch(canProvider(Permission.viewCost));
    final t = Theme.of(context).textTheme;
    Widget pair(Widget a, Widget b) => context.isMobile
        ? Column(children: [a, const SizedBox(height: 14), b])
        : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: a),
            const SizedBox(width: 12),
            Expanded(child: b),
          ]);

    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(label: 'اسم المنتج التصنيعي', controller: _name, autofocus: _isNew,
              validator: (v) => Validators.required(v, 'اسم المنتج')),
          const SizedBox(height: 14),
          pair(
            AmountField(
              label: 'سعر البيع',
              controller: _price,
              allowZero: true,
              onChanged: (_) => setState(() {}),
            ),
            AppTextField(label: 'الوحدة', controller: _unit),
          ),
          const SizedBox(height: 14),
          pair(
            AppTextField(label: 'الكود (SKU)', controller: _sku),
            AppTextField(label: 'الباركود', controller: _barcode, prefixIcon: Symbols.barcode),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: Text('المكونات (لكل وحدة واحدة)', style: t.titleSmall)),
              TextButton.icon(
                onPressed: _addComponent,
                icon: const Icon(Symbols.add, size: 18),
                label: const Text('إضافة مكوّن'),
              ),
            ],
          ),
          Text(
            'عند البيع تُخصم هذه الكميات من المخزون تلقائياً مضروبة في الكمية المباعة.',
            style: t.bodySmall,
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
          else if (_rows.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('لم تتم إضافة مكونات بعد.', textAlign: TextAlign.center),
            )
          else
            for (final r in _rows) _componentRow(r, canCost),
          if (canCost && _rows.isNotEmpty) ...[
            const SizedBox(height: 12),
            _summary(),
          ],
          const SizedBox(height: 14),
          AppTextField(label: 'الوصف', controller: _description, maxLines: 2),
          const SizedBox(height: 20),
          PrimaryButton(label: 'حفظ', icon: Symbols.save, onPressed: _loading ? null : _save, loading: _saving, expand: true),
          if (!_isNew) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _toggleActive,
              child: Text(widget.product!.active ? 'إيقاف المنتج' : 'تفعيل المنتج'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _componentRow(_Row r, bool canCost) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (canCost)
                    Text('تكلفة الوحدة: ${ref.watch(moneyFormatterProvider)(r.unitCost)}', style: t.bodySmall),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 120,
            child: AppTextField(
              label: r.unit.isEmpty ? 'الكمية' : 'الكمية (${r.unit})',
              controller: r.qty,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: Validators.quantity,
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (canCost) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 90,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: MoneyText(r.cost, style: t.bodyMedium),
              ),
            ),
          ],
          IconButton(
            tooltip: 'حذف المكوّن',
            icon: const Icon(Symbols.delete, color: AppColors.danger, size: 20),
            onPressed: () => _removeComponent(r),
          ),
        ],
      ),
    );
  }

  Widget _summary() {
    final t = Theme.of(context).textTheme;
    final price = Money.parse(_price.text) ?? 0;
    final profit = price - _cost;
    final margin = price == 0 ? 0.0 : profit / price * 100;
    Widget line(String label, Widget value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [Expanded(child: Text(label, style: t.bodyMedium)), value]),
        );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          line('التكلفة الحالية للوحدة', MoneyText(_cost, style: t.titleSmall)),
          line('سعر البيع', MoneyText(price, style: t.titleSmall)),
          line(
            'الربح المتوقع للوحدة',
            Text(
              '${ref.watch(moneyFormatterProvider)(profit)}  (${margin.toStringAsFixed(1)}%)',
              style: t.titleSmall?.copyWith(color: profit < 0 ? AppColors.danger : AppColors.success),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'التكلفة الفعلية تُحسب وقت البيع من متوسط تكلفة المكونات في ذلك الوقت.',
            style: t.bodySmall,
          ),
        ],
      ),
    );
  }
}
