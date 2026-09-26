import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/accounting/invoice_calculator.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/fields.dart';
import '../../../core/widgets/money_text.dart';
import '../../catalog/application/catalog_providers.dart';
import '../../catalog/domain/catalog_item.dart';

/// Searchable picker of products (and services for sales). Exact barcode
/// matches are resolved too, so a USB barcode scanner (keyboard wedge)
/// works out of the box.
///
/// Manufactured products are sellable but hold no stock, so they are offered
/// only when [includeManufactured] is true (sales), never for purchases or as
/// components of another recipe.
Future<Sellable?> showItemSearch(
  BuildContext context, {
  required bool includeServices,
  bool? includeManufactured,
  String title = 'إضافة صنف',
}) {
  return showDialog<Sellable>(
    context: context,
    builder: (_) => _ItemSearchDialog(
      includeServices: includeServices,
      includeManufactured: includeManufactured ?? includeServices,
      title: title,
    ),
  );
}

class _ItemSearchDialog extends ConsumerStatefulWidget {
  const _ItemSearchDialog({required this.includeServices, required this.includeManufactured, required this.title});
  final bool includeServices;
  final bool includeManufactured;
  final String title;

  @override
  ConsumerState<_ItemSearchDialog> createState() => _ItemSearchDialogState();
}

class _ItemSearchDialogState extends ConsumerState<_ItemSearchDialog> {
  List<Sellable>? _results;
  String _query = '';
  LineKind? _filter;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  Future<void> _search(String q) async {
    _query = q;
    final repo = ref.read(catalogRepositoryProvider);
    final wantProducts = _filter != LineKind.service;
    final wantServices = widget.includeServices && _filter != LineKind.product;
    final results = await Future.wait([
      if (wantProducts) repo.searchProducts(q).then((l) => l.map(Sellable.product).toList()),
      if (wantServices) repo.searchServices(q).then((l) => l.map(Sellable.service).toList()),
    ]);
    bool allowed(Sellable s) => widget.includeManufactured || !s.isManufactured;
    var list = [for (final r in results) ...r.where(allowed)];
    if (list.isEmpty && q.trim().isNotEmpty && wantProducts) {
      final byBarcode = await repo.productByBarcode(q);
      if (byBarcode != null && byBarcode.active && allowed(Sellable.product(byBarcode))) {
        list = [Sellable.product(byBarcode)];
      }
    }
    if (mounted && _query == q) setState(() => _results = list);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: SizedBox(
        width: 560,
        height: 600,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.title, style: t.titleLarge),
              const SizedBox(height: 12),
              SearchField(onChanged: _search, autofocus: true, hint: 'اسم الصنف أو الكود أو الباركود...'),
              if (widget.includeServices) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final f in [null, LineKind.product, LineKind.service])
                      ChoiceChip(
                        showCheckmark: false,
                        selected: _filter == f,
                        label: Text(switch (f) {
                          null => 'الكل',
                          LineKind.product => 'المنتجات',
                          LineKind.service => 'الخدمات',
                        }),
                        onSelected: (_) {
                          setState(() {
                            _filter = f;
                            _results = null;
                          });
                          _search(_query);
                        },
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              const Divider(),
              Expanded(
                child: _results == null
                    ? const Center(child: CircularProgressIndicator())
                    : _results!.isEmpty
                        ? const Center(child: Text('لا توجد أصناف مطابقة. أضف الأصناف من شاشة المنتجات أو الخدمات.'))
                        : ListView.separated(
                            itemCount: _results!.length,
                            separatorBuilder: (_, _) => const Divider(),
                            itemBuilder: (context, i) {
                              final item = _results![i];
                              final isService = item.kind == LineKind.service;
                              final isStock = !isService && !item.isManufactured;
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isService ? AppColors.infoSoft : AppColors.primarySoft,
                                  child: Icon(
                                    isService
                                        ? Symbols.home_repair_service
                                        : item.isManufactured
                                            ? Symbols.precision_manufacturing
                                            : Symbols.inventory_2,
                                    size: 20,
                                    color: isService ? AppColors.info : AppColors.primary,
                                  ),
                                ),
                                title: Text(item.name),
                                subtitle: Text(
                                  isService
                                      ? 'خدمة'
                                      : item.isManufactured
                                          ? 'منتج تصنيعي - يُخصم من مكوناته'
                                          : 'المخزون: ${formatQuantity(item.stockQty ?? 0)} ${item.unit}',
                                  style: t.bodySmall?.copyWith(
                                    color: isStock && (item.stockQty ?? 0) <= 0 ? AppColors.danger : null,
                                  ),
                                ),
                                trailing: MoneyText(widget.includeServices ? item.price : item.cost),
                                onTap: () => Navigator.pop(context, item),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
