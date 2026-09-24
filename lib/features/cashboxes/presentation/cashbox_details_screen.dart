import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/export/exporter.dart';
import '../../../core/pdf/pdf_documents.dart';
import '../../../core/permissions/permissions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/period_selector.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../core/widgets/statement_view.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/states.dart';
import '../../auth/application/auth_providers.dart';
import '../../settings/application/settings_providers.dart';
import '../application/cashbox_providers.dart';
import '../domain/cashbox.dart';
import 'cashbox_form.dart';

class CashboxDetailsScreen extends ConsumerStatefulWidget {
  const CashboxDetailsScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<CashboxDetailsScreen> createState() => _CashboxDetailsScreenState();
}

class _CashboxDetailsScreenState extends ConsumerState<CashboxDetailsScreen> {
  Period _period = Period.of(PeriodPreset.month);

  Future<void> _print(Cashbox box) async {
    final st = await ref.read(cashboxStatementProvider((widget.id, _period.range)).future);
    if (!mounted) return;
    await Exporter.pdfActions(
      context,
      fileName: 'كشف ${box.name}',
      build: () => PdfDocuments.statement(
        settings: ref.read(companySettingsProvider),
        title: 'كشف حركة خزنة',
        accountName: box.name,
        range: _period.range,
        statement: st,
        increaseLabel: 'وارد',
        decreaseLabel: 'منصرف',
      ),
    );
  }

  Future<void> _toggle(Cashbox box) async {
    if (box.active && box.balance != 0) {
      final ok = await AppDialog.confirm(
        context,
        title: 'إيقاف خزنة بها رصيد',
        message: 'رصيد "${box.name}" لا يساوي صفراً. يفضل تحويل الرصيد لخزنة أخرى أولاً. هل تريد المتابعة؟',
      );
      if (!ok) return;
    }
    if (!mounted) return;
    await runWithFeedback(
      context,
      () => ref.read(cashboxRepositoryProvider).setActive(box, !box.active, ref.read(currentUserProvider)!),
      success: 'تم الحفظ',
    );
  }

  @override
  Widget build(BuildContext context) {
    final box = ref.watch(cashboxProvider(widget.id));
    final canManage = ref.watch(canProvider(Permission.manageCashboxes));
    final canTransfer = ref.watch(canProvider(Permission.createTransfer));
    return box.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, s) => Scaffold(body: ErrorState(error: e, stackTrace: s)),
      data: (b) => PageScaffold(
        title: b.name,
        subtitle: b.kind.label,
        actions: [
          if (canTransfer && b.active)
            OutlinedButton.icon(
              onPressed: () => context.push('/transfers/new?from=${b.id}'),
              icon: const Icon(Symbols.swap_horiz),
              label: const Text('تحويل'),
            ),
          IconButton(tooltip: 'طباعة الكشف', onPressed: () => _print(b), icon: const Icon(Symbols.print)),
          if (canManage)
            PopupMenuButton<String>(
              onSelected: (v) => v == 'edit' ? showCashboxForm(context, cashbox: b) : _toggle(b),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('تعديل')),
                PopupMenuItem(value: 'toggle', child: Text(b.active ? 'إيقاف' : 'تفعيل')),
              ],
            ),
        ],
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ResponsiveGrid(
              minItemWidth: 200,
              maxColumns: 3,
              children: [
                StatCard(label: 'الرصيد الحالي', icon: Symbols.account_balance_wallet, amount: b.balance,
                    tone: b.balance < 0 ? Tone.danger : Tone.primary),
                StatCard(label: 'إجمالي الوارد', icon: Symbols.arrow_downward, amount: b.totalIn, tone: Tone.success),
                StatCard(label: 'إجمالي المنصرف', icon: Symbols.arrow_upward, amount: b.totalOut, tone: Tone.danger),
              ],
            ),
            const SizedBox(height: 16),
            PeriodSelector(value: _period, onChanged: (p) => setState(() => _period = p)),
            const SizedBox(height: 12),
            AsyncView(
              value: ref.watch(cashboxStatementProvider((widget.id, _period.range))),
              data: (st) => StatementView(
                statement: st,
                increaseLabel: 'وارد',
                decreaseLabel: 'منصرف',
                increaseTone: Tone.success,
                decreaseTone: Tone.danger,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
