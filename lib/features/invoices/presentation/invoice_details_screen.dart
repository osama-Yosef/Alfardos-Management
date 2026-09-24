import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/accounting/invoice_calculator.dart';
import '../../../core/export/exporter.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/money/money.dart';
import '../../../core/pdf/pdf_documents.dart';
import '../../../core/permissions/permissions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_data_table.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/money_text.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/application/auth_providers.dart';
import '../../settings/application/settings_providers.dart';
import '../application/invoice_providers.dart';
import '../domain/invoice.dart';

class InvoiceDetailsScreen extends ConsumerWidget {
  const InvoiceDetailsScreen({super.key, required this.kind, required this.id});

  final InvoiceKind kind;
  final String id;

  Future<void> _cancel(BuildContext context, WidgetRef ref, Invoice inv) async {
    final reason = await AppDialog.cancelReason(
      context,
      title: 'إلغاء ${kind.title} ${inv.number}',
      message: 'لن تُحذف الفاتورة. سيُسجل قيد عكسي بتاريخ اليوم يعيد أرصدة الخزنة '
          'و${kind.partyLabel} والمخزون، وتبقى الفاتورة في السجلات بحالة "ملغاة".',
    );
    if (reason == null || !context.mounted) return;
    await runWithFeedback(
      context,
      () => ref.read(invoiceRepositoryProvider(kind)).cancel(inv, reason, ref.read(ledgerProvider)),
      success: 'تم إلغاء الفاتورة',
    );
  }

  void _print(BuildContext context, WidgetRef ref, Invoice inv) {
    Exporter.pdfActions(
      context,
      fileName: '${kind.title} ${inv.number}',
      build: () => PdfDocuments.invoice(inv, ref.read(companySettingsProvider)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoice = ref.watch(invoiceProvider((kind, id)));
    final canCancel = ref.watch(canProvider(kind.cancel));
    final canCost = ref.watch(canProvider(Permission.viewCost));
    return invoice.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, s) => Scaffold(body: ErrorState(error: e, stackTrace: s)),
      data: (inv) {
        final t = Theme.of(context).textTheme;
        final header = AppCard(
          child: Wrap(
            spacing: 32,
            runSpacing: 12,
            children: [
              _Meta('رقم الفاتورة', Text(inv.number, style: t.titleMedium)),
              _Meta('التاريخ', Text(Dates.formatTime(inv.date))),
              _Meta(
                kind.partyLabel,
                inv.partyId == null
                    ? Text(inv.partyName)
                    : InkWell(
                        onTap: () => context.push('${kind.partyKind.route}/${inv.partyId}'),
                        child: Text(inv.partyName,
                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                      ),
              ),
              _Meta('الحالة', StatusBadge.invoice(cancelled: inv.cancelled, payment: inv.paymentStatus)),
              if (inv.paid > 0) _Meta('الخزنة', Text('${inv.cashboxName} • ${inv.method.label}')),
              _Meta('بواسطة', Text(inv.createdByName)),
            ],
          ),
        );

        final lines = Card(
          clipBehavior: Clip.antiAlias,
          child: AppDataTable(
            columns: [
              const AppColumn('الصنف', flex: 3, minWidth: 200),
              const AppColumn('الكمية', numeric: true, minWidth: 70),
              AppColumn(kind.priceLabel, numeric: true),
              const AppColumn('الإجمالي', numeric: true),
              if (canCost && kind.isSale) const AppColumn('التكلفة', numeric: true),
              if (canCost && kind.isSale) const AppColumn('الربح', numeric: true),
            ],
            rows: [
              for (final l in inv.lines)
                [
                  Row(children: [
                    Flexible(child: Text(l.name, overflow: TextOverflow.ellipsis)),
                    if (l.kind == LineKind.service) ...[
                      const SizedBox(width: 6),
                      const StatusBadge('خدمة', tone: Tone.info),
                    ],
                  ]),
                  Text(formatQuantity(l.quantity)),
                  MoneyText(l.unitPrice),
                  MoneyText(l.gross),
                  if (canCost && kind.isSale) MoneyText(l.cost),
                  if (canCost && kind.isSale) MoneyText(l.profit, autoTone: true),
                ],
            ],
          ),
        );

        final totals = AppCard(
          title: 'الملخص',
          child: Column(
            children: [
              InfoRow(label: 'المجموع', value: MoneyText(inv.subtotal)),
              if (inv.discount > 0) InfoRow(label: 'الخصم', value: MoneyText(inv.discount, tone: Tone.danger)),
              InfoRow(label: 'الصافي', emphasize: true, value: MoneyText(inv.total)),
              const Divider(),
              InfoRow(label: 'المدفوع', value: MoneyText(inv.paid, tone: Tone.success)),
              InfoRow(label: 'المتبقي', value: MoneyText(inv.remaining, tone: inv.remaining > 0 ? Tone.danger : Tone.neutral)),
              if (canCost && kind.isSale) ...[
                const Divider(),
                InfoRow(label: 'تكلفة المنتجات', value: MoneyText(inv.productCost)),
                if (inv.serviceCost > 0) InfoRow(label: 'تكلفة الخدمات', value: MoneyText(inv.serviceCost)),
                InfoRow(label: 'إجمالي الربح', emphasize: true, value: MoneyText(inv.grossProfit, autoTone: true)),
              ],
            ],
          ),
        );

        final extra = [
          if (inv.notes.isNotEmpty) AppCard(title: 'ملاحظات', child: Text(inv.notes)),
          if (inv.cancelled)
            AppCard(
              color: AppColors.dangerSoft,
              title: 'فاتورة ملغاة',
              child: Text('السبب: ${inv.cancelReason ?? '-'}\nبواسطة: ${inv.cancelledByName ?? '-'}'),
            ),
        ];

        return PageScaffold(
          title: '${kind.title} ${inv.number}',
          actions: [
            FilledButton.tonalIcon(
              onPressed: () => _print(context, ref, inv),
              icon: const Icon(Symbols.print),
              label: const Text('طباعة / مشاركة'),
            ),
            if (ref.watch(canProvider(kind.create)))
              OutlinedButton.icon(
                onPressed: () => context.push('${kind.route}/new?copy=${inv.id}'),
                icon: const Icon(Symbols.content_copy),
                label: Text(inv.cancelled ? 'إعادة إصدار' : 'نسخ لفاتورة جديدة'),
              ),
            if (canCancel && !inv.cancelled)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                onPressed: () => _cancel(context, ref, inv),
                icon: const Icon(Symbols.cancel),
                label: const Text('إلغاء الفاتورة'),
              ),
          ],
          body: context.isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [header, const SizedBox(height: 12), lines],
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 360,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          totals,
                          for (final e in extra) ...[const SizedBox(height: 12), e],
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    header,
                    const SizedBox(height: 12),
                    lines,
                    const SizedBox(height: 12),
                    totals,
                    for (final e in extra) ...[const SizedBox(height: 12), e],
                  ],
                ),
        );
      },
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.label, this.value);
  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        value,
      ],
    );
  }
}
