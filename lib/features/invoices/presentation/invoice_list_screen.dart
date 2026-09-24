import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/utils/dates.dart';
import '../../../core/widgets/fields.dart';
import '../../../core/widgets/live_query_list.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/period_selector.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/states.dart';
import '../../auth/application/auth_providers.dart';
import '../application/invoice_providers.dart';
import '../data/invoice_repository.dart';
import '../domain/invoice.dart';
import 'invoice_tile.dart';

class InvoiceListScreen extends ConsumerStatefulWidget {
  const InvoiceListScreen({super.key, required this.kind});

  final InvoiceKind kind;

  @override
  ConsumerState<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends ConsumerState<InvoiceListScreen> {
  String _search = '';
  InvoiceFilter _filter = InvoiceFilter.all;
  Period? _period;

  @override
  Widget build(BuildContext context) {
    final kind = widget.kind;
    final canCreate = ref.watch(canProvider(kind.create));
    final query = ref.watch(invoiceRepositoryProvider(kind)).query(
          search: _search,
          filter: _filter,
          range: _period?.range,
        );
    void create() => context.push('${kind.route}/new');

    final filters = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final f in InvoiceFilter.values)
          ChoiceChip(
            showCheckmark: false,
            selected: _filter == f,
            label: Text(switch (f) {
              InvoiceFilter.all => 'الكل',
              InvoiceFilter.unpaid => 'غير مسددة',
              InvoiceFilter.cancelled => 'ملغاة',
            }),
            onSelected: (_) => setState(() => _filter = f),
          ),
        ActionChip(
          avatar: const Icon(Symbols.date_range, size: 18),
          label: Text(_period?.label ?? 'كل التواريخ'),
          onPressed: () async {
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2015),
              lastDate: DateTime.now().add(const Duration(days: 1)),
            );
            if (picked != null) {
              setState(() => _period = Period(PeriodPreset.custom, DateRange(picked.start, picked.end)));
            }
          },
        ),
        if (_period != null)
          IconButton(
            tooltip: 'إزالة فلتر التاريخ',
            icon: const Icon(Symbols.close, size: 18),
            onPressed: () => setState(() => _period = null),
          ),
      ],
    );

    return PageScaffold(
      title: kind.plural,
      actions: [
        if (canCreate && !context.isMobile)
          FilledButton.icon(onPressed: create, icon: const Icon(Symbols.add), label: Text(kind.title)),
      ],
      floatingAction: canCreate && context.isMobile
          ? FloatingActionButton.extended(onPressed: create, icon: const Icon(Symbols.add), label: Text(kind.title))
          : null,
      body: ListPageBody(
        toolbar: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: context.isMobile ? double.infinity : 380,
              child: SearchField(
                onChanged: (v) => setState(() => _search = v),
                hint: 'رقم الفاتورة أو اسم ${kind.partyLabel}...',
              ),
            ),
            const SizedBox(height: 10),
            filters,
          ],
        ),
        child: LiveQueryList<Invoice>(
          query: query,
          fromDoc: (d) => Invoice.fromDoc(kind, d),
          empty: EmptyState(
            icon: kind.isSale ? Symbols.receipt_long : Symbols.shopping_cart,
            title: _search.isEmpty && _filter == InvoiceFilter.all && _period == null
                ? 'لا توجد ${kind.isSale ? 'فواتير مبيعات' : 'فواتير مشتريات'} حتى الآن'
                : 'لا توجد فواتير مطابقة',
            actionLabel: canCreate ? 'إنشاء فاتورة' : null,
            onAction: create,
          ),
          itemBuilder: (_, inv, _) => InvoiceTile(invoice: inv),
        ),
      ),
    );
  }
}
