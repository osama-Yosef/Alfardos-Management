import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/export/exporter.dart';
import '../../../core/pdf/pdf_documents.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/live_query_list.dart';
import '../../../core/widgets/money_text.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/period_selector.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../core/widgets/statement_view.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/application/auth_providers.dart';
import '../../invoices/application/invoice_providers.dart';
import '../../invoices/domain/invoice.dart';
import '../../invoices/presentation/invoice_tile.dart';
import '../../settings/application/settings_providers.dart';
import '../application/party_providers.dart';
import '../domain/party.dart';
import '../domain/payment.dart';
import 'party_form.dart';
import 'payment_tile.dart';

enum _Tab { statement, invoices, payments }

class PartyDetailsScreen extends ConsumerStatefulWidget {
  const PartyDetailsScreen({super.key, required this.kind, required this.id});

  final PartyKind kind;
  final String id;

  @override
  ConsumerState<PartyDetailsScreen> createState() => _PartyDetailsScreenState();
}

class _PartyDetailsScreenState extends ConsumerState<PartyDetailsScreen> {
  _Tab _tab = _Tab.statement;
  Period _period = Period.of(PeriodPreset.year);

  InvoiceKind get _invoiceKind => widget.kind.isCustomer ? InvoiceKind.sale : InvoiceKind.purchase;
  String get _paymentsPath => widget.kind.isCustomer ? '/receipts' : '/supplier-payments';

  Future<void> _printStatement(Party party) async {
    final statement = await ref.read(partyStatementProvider((widget.kind, widget.id, _period.range)).future);
    if (!mounted) return;
    await Exporter.pdfActions(
      context,
      fileName: 'كشف حساب ${party.name}',
      build: () => PdfDocuments.statement(
        settings: ref.read(companySettingsProvider),
        title: 'كشف حساب ${widget.kind.singular}',
        accountName: party.name,
        range: _period.range,
        statement: statement,
        increaseLabel: widget.kind.increaseLabel,
        decreaseLabel: widget.kind.decreaseLabel,
      ),
    );
  }

  Future<void> _toggleActive(Party party) async {
    final ok = await AppDialog.confirm(
      context,
      title: party.active ? 'إيقاف ${widget.kind.singular}' : 'تفعيل ${widget.kind.singular}',
      message: party.active
          ? 'لن يظهر "${party.name}" في قوائم الاختيار، مع الاحتفاظ بكامل سجله المالي.'
          : 'سيعود "${party.name}" للظهور في قوائم الاختيار.',
    );
    if (!ok || !mounted) return;
    await runWithFeedback(
      context,
      () => ref.read(partyRepositoryProvider(widget.kind)).setActive(party, !party.active, ref.read(currentUserProvider)!),
      success: 'تم الحفظ',
    );
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.kind;
    final party = ref.watch(partyProvider((kind, widget.id)));
    final canPay = ref.watch(canProvider(kind.pay));
    final canInvoice = ref.watch(canProvider(_invoiceKind.create));
    final canManage = ref.watch(canProvider(kind.manage));

    return party.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, s) => Scaffold(body: ErrorState(error: e, stackTrace: s)),
      data: (p) => PageScaffold(
        title: p.name,
        subtitle: [kind.singular, if (p.phone.isNotEmpty) p.phone, if (p.address.isNotEmpty) p.address].join(' • '),
        actions: [
          if (canPay && p.active)
            FilledButton.icon(
              onPressed: () => context.push('$_paymentsPath/new?party=${p.id}'),
              icon: Icon(kind.isCustomer ? Symbols.call_received : Symbols.call_made),
              label: Text(kind.isCustomer ? 'تحصيل' : 'دفع'),
            ),
          if (canInvoice && p.active && !context.isMobile)
            OutlinedButton.icon(
              onPressed: () => context.push('${_invoiceKind.route}/new?party=${p.id}'),
              icon: const Icon(Symbols.add),
              label: Text(_invoiceKind.title),
            ),
          PopupMenuButton<String>(
            tooltip: 'المزيد',
            onSelected: (v) {
              switch (v) {
                case 'edit':
                  showPartyForm(context, kind, party: p);
                case 'invoice':
                  context.push('${_invoiceKind.route}/new?party=${p.id}');
                case 'print':
                  _printStatement(p);
                case 'active':
                  _toggleActive(p);
              }
            },
            itemBuilder: (_) => [
              if (canInvoice && p.active && context.isMobile)
                PopupMenuItem(value: 'invoice', child: Text(_invoiceKind.title)),
              const PopupMenuItem(value: 'print', child: Text('طباعة كشف الحساب')),
              if (canManage) const PopupMenuItem(value: 'edit', child: Text('تعديل البيانات')),
              if (canManage) PopupMenuItem(value: 'active', child: Text(p.active ? 'إيقاف' : 'تفعيل')),
            ],
          ),
        ],
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!p.active)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Align(alignment: AlignmentDirectional.centerStart, child: StatusBadge.active(false)),
              ),
            ResponsiveGrid(
              minItemWidth: 200,
              children: [
                StatCard(
                  label: kind.balanceLabel,
                  icon: Symbols.account_balance,
                  amount: p.balance,
                  tone: p.balance > 0 ? (kind.isCustomer ? Tone.danger : Tone.warning) : Tone.success,
                ),
                StatCard(label: kind.totalIncreaseLabel, icon: Symbols.trending_up, amount: p.totalIncrease, tone: Tone.primary),
                StatCard(label: kind.totalDecreaseLabel, icon: Symbols.payments, amount: p.totalDecrease, tone: Tone.success),
                StatCard(
                  label: 'عدد الفواتير',
                  icon: Symbols.receipt_long,
                  value: '${p.invoiceCount}',
                  tone: Tone.info,
                  hint: p.lastTxAt == null ? 'لا توجد حركات' : 'آخر حركة: ${Dates.format(p.lastTxAt!)}',
                ),
              ],
            ),
            const SizedBox(height: 16),
            SegmentedButton<_Tab>(
              segments: const [
                ButtonSegment(value: _Tab.statement, label: Text('كشف الحساب'), icon: Icon(Symbols.list_alt)),
                ButtonSegment(value: _Tab.invoices, label: Text('الفواتير'), icon: Icon(Symbols.receipt_long)),
                ButtonSegment(value: _Tab.payments, label: Text('المدفوعات'), icon: Icon(Symbols.payments)),
              ],
              selected: {_tab},
              onSelectionChanged: (s) => setState(() => _tab = s.first),
            ),
            const SizedBox(height: 14),
            switch (_tab) {
              _Tab.statement => _statement(p),
              _Tab.invoices => LiveQueryList<Invoice>(
                  query: ref.watch(invoiceRepositoryProvider(_invoiceKind)).query(partyId: p.id),
                  fromDoc: (d) => Invoice.fromDoc(_invoiceKind, d),
                  empty: const EmptyState(icon: Symbols.receipt_long, title: 'لا توجد فواتير', compact: true),
                  itemBuilder: (_, inv, _) => InvoiceTile(invoice: inv),
                ),
              _Tab.payments => LiveQueryList<Payment>(
                  query: ref.watch(partyRepositoryProvider(kind)).paymentsQuery(partyId: p.id),
                  fromDoc: (d) => Payment.fromDoc(kind, d),
                  empty: const EmptyState(icon: Symbols.payments, title: 'لا توجد مدفوعات', compact: true),
                  itemBuilder: (_, pay, _) => PaymentTile(payment: pay, showParty: false),
                ),
            },
          ],
        ),
      ),
    );
  }

  Widget _statement(Party p) {
    final statement = ref.watch(partyStatementProvider((widget.kind, widget.id, _period.range)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: PeriodSelector(value: _period, onChanged: (v) => setState(() => _period = v))),
            IconButton(
              tooltip: 'طباعة / مشاركة',
              onPressed: () => _printStatement(p),
              icon: const Icon(Symbols.print),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AsyncView(
          value: statement,
          data: (s) => StatementView(
            statement: s,
            increaseLabel: widget.kind.increaseLabel,
            decreaseLabel: widget.kind.decreaseLabel,
            increaseTone: widget.kind.isCustomer ? Tone.danger : Tone.warning,
          ),
        ),
        if (p.notes.isNotEmpty) ...[
          const SizedBox(height: 12),
          AppCard(title: 'ملاحظات', child: Text(p.notes)),
        ],
        const SizedBox(height: 4),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('الرصيد الحالي: ', style: Theme.of(context).textTheme.bodySmall),
                MoneyText(p.balance, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
