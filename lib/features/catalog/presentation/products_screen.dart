import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../../core/money/money.dart';
import '../../../core/permissions/permissions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/fields.dart';
import '../../../core/widgets/live_query_list.dart';
import '../../../core/widgets/money_text.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/application/auth_providers.dart';
import '../../settings/application/settings_providers.dart';
import '../application/catalog_providers.dart';
import '../data/catalog_repository.dart';
import '../domain/catalog_item.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  late String _search = widget.initialQuery;
  ProductFilter _filter = ProductFilter.all;

  @override
  Widget build(BuildContext context) {
    final canManage = ref.watch(canProvider(Permission.manageCatalog));
    final canCost = ref.watch(canProvider(Permission.viewCost));
    final query = ref.watch(catalogRepositoryProvider).productsQuery(search: _search, filter: _filter);
    void add() => _showProductForm(context);

    return PageScaffold(
      title: 'المنتجات والمخزون',
      actions: [
        if (canManage && !context.isMobile)
          FilledButton.icon(onPressed: add, icon: const Icon(Symbols.add), label: const Text('إضافة منتج')),
      ],
      floatingAction: canManage && context.isMobile
          ? FloatingActionButton(onPressed: add, child: const Icon(Symbols.add))
          : null,
      body: ListPageBody(
        toolbar: Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: context.isMobile ? double.infinity : 340,
              child: SearchField(
                initial: widget.initialQuery,
                onChanged: (v) => setState(() => _search = v),
                hint: 'الاسم أو الكود أو الباركود...',
              ),
            ),
            for (final f in ProductFilter.values)
              ChoiceChip(
                showCheckmark: false,
                selected: _filter == f,
                label: Text(switch (f) {
                  ProductFilter.all => 'الكل',
                  ProductFilter.lowStock => 'حسب المخزون (الأقل أولاً)',
                  ProductFilter.inactive => 'موقوف',
                }),
                onSelected: (_) => setState(() => _filter = f),
              ),
          ],
        ),
        child: LiveQueryList<Product>(
          query: query,
          fromDoc: Product.fromDoc,
          empty: EmptyState(
            icon: Symbols.inventory_2,
            title: _search.isEmpty ? 'لا توجد منتجات حتى الآن' : 'لا توجد نتائج مطابقة',
            message: _search.isEmpty ? 'أضف منتجاتك لتتمكن من بيعها وشرائها ومتابعة المخزون.' : null,
            actionLabel: canManage && _search.isEmpty ? 'إضافة منتج' : null,
            onAction: add,
          ),
          itemBuilder: (context, p, _) => ListTile(
            onTap: canManage ? () => _showProductForm(context, product: p) : null,
            leading: CircleAvatar(
              backgroundColor: p.isLowStock || p.stockQty <= 0 ? AppColors.warningSoft : AppColors.primarySoft,
              child: Icon(Symbols.inventory_2, size: 20,
                  color: p.isLowStock || p.stockQty <= 0 ? AppColors.warning : AppColors.primary),
            ),
            title: Row(children: [
              Flexible(child: Text(p.name, overflow: TextOverflow.ellipsis)),
              if (!p.active) ...[const SizedBox(width: 8), StatusBadge.active(false)],
              if (p.active && p.isLowStock) ...[
                const SizedBox(width: 8),
                const StatusBadge('مخزون منخفض', tone: Tone.warning),
              ],
            ]),
            subtitle: Text(
              [
                'المخزون: ${formatQuantity(p.stockQty)} ${p.unit}',
                if (canCost) 'التكلفة: ${ref.watch(moneyFormatterProvider)(p.costPrice)}',
                if (p.sku.isNotEmpty) 'كود: ${p.sku}',
              ].join(' • '),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            trailing: MoneyText(p.sellPrice, style: Theme.of(context).textTheme.titleSmall),
          ),
        ),
      ),
    );
  }
}

Future<void> _showProductForm(BuildContext context, {Product? product}) {
  return AppDialog.show(
    context,
    title: product == null ? 'إضافة منتج' : 'تعديل ${product.name}',
    child: _ProductForm(product: product),
  );
}

class _ProductForm extends ConsumerStatefulWidget {
  const _ProductForm({this.product});
  final Product? product;

  @override
  ConsumerState<_ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends ConsumerState<_ProductForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.product?.name);
  late final _sku = TextEditingController(text: widget.product?.sku);
  late final _barcode = TextEditingController(text: widget.product?.barcode);
  late final _unit = TextEditingController(text: widget.product?.unit ?? 'قطعة');
  late final _price = TextEditingController(text: widget.product == null ? '' : Money.toInput(widget.product!.sellPrice));
  late final _cost = TextEditingController(text: widget.product == null ? '' : Money.toInput(widget.product!.costPrice));
  late final _lowStock = TextEditingController(
      text: widget.product == null || widget.product!.lowStockAlert == 0 ? '' : formatQuantity(widget.product!.lowStockAlert));
  final _openingQty = TextEditingController();
  late final _description = TextEditingController(text: widget.product?.description);
  bool _saving = false;

  bool get _isNew => widget.product == null;
  bool get _costEditable => _isNew || widget.product!.stockQty <= 0;

  @override
  void dispose() {
    for (final c in [_name, _sku, _barcode, _unit, _price, _cost, _lowStock, _openingQty, _description]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final repo = ref.read(catalogRepositoryProvider);
    final user = ref.read(currentUserProvider)!;
    final input = ProductInput(
      name: _name.text,
      sku: _sku.text,
      barcode: _barcode.text,
      unit: _unit.text,
      sellPrice: Money.parse(_price.text) ?? 0,
      lowStockAlert: Validators.parseQuantity(_lowStock.text) ?? 0,
      description: _description.text,
    );
    final cost = Money.parse(_cost.text) ?? 0;
    final ok = await runWithFeedback(context, () async {
      if (_isNew) {
        await repo.createProduct(
          input,
          costPrice: cost,
          openingQty: Validators.parseQuantity(_openingQty.text) ?? 0,
          user: user,
          ledger: ref.read(ledgerProvider),
        );
      } else {
        await repo.updateProduct(widget.product!, input, user, costPrice: _costEditable ? cost : null);
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
          AppTextField(label: 'اسم المنتج', controller: _name, autofocus: _isNew,
              validator: (v) => Validators.required(v, 'اسم المنتج')),
          const SizedBox(height: 14),
          pair(
            AppTextField(label: 'الكود (SKU)', controller: _sku),
            AppTextField(label: 'الباركود', controller: _barcode, prefixIcon: Symbols.barcode),
          ),
          const SizedBox(height: 14),
          pair(
            AmountField(label: 'سعر البيع', controller: _price, allowZero: true),
            AmountField(
              label: 'التكلفة للوحدة',
              controller: _cost,
              allowZero: true,
              required: false,
              enabled: _costEditable,
              helper: _costEditable
                  ? 'تُحدَّث تلقائياً بمتوسط التكلفة مع كل فاتورة شراء.'
                  : 'متوسط التكلفة يُحسب تلقائياً من المشتريات.',
            ),
          ),
          const SizedBox(height: 14),
          pair(
            AppTextField(label: 'الوحدة', controller: _unit),
            AppTextField(
              label: 'حد التنبيه للمخزون',
              controller: _lowStock,
              keyboardType: TextInputType.number,
              validator: (v) => v == null || v.isEmpty ? null : Validators.quantity(v),
            ),
          ),
          if (_isNew) ...[
            const SizedBox(height: 14),
            AppTextField(
              label: 'الكمية الافتتاحية في المخزون (اختياري)',
              controller: _openingQty,
              keyboardType: TextInputType.number,
              helper: 'تُسجَّل بقيمة التكلفة أعلاه كرصيد افتتاحي للمخزون.',
              validator: (v) => v == null || v.isEmpty ? null : Validators.quantity(v),
            ),
          ],
          const SizedBox(height: 14),
          AppTextField(label: 'الوصف', controller: _description, maxLines: 2),
          const SizedBox(height: 20),
          PrimaryButton(label: 'حفظ', icon: Symbols.save, onPressed: _save, loading: _saving, expand: true),
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
}
