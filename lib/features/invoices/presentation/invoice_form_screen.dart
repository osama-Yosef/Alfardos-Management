import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/money_text.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/responsive.dart';
import '../../cashboxes/application/cashbox_providers.dart';
import '../../parties/application/party_providers.dart';
import '../../parties/presentation/party_picker.dart';
import '../application/invoice_form_controller.dart';
import '../application/invoice_providers.dart';
import '../domain/invoice.dart';
import 'invoice_lines_editor.dart';
import 'invoice_summary_panel.dart';

/// Sales / purchase invoice entry. Flow: choose party → add items →
/// choose payment → save. Everything else has sensible defaults.
class InvoiceFormScreen extends ConsumerStatefulWidget {
  const InvoiceFormScreen({super.key, required this.kind, this.partyId, this.copyFromId});

  final InvoiceKind kind;
  final String? partyId;

  /// Existing invoice whose lines pre-fill this one (correction flow).
  final String? copyFromId;

  @override
  ConsumerState<InvoiceFormScreen> createState() => _InvoiceFormScreenState();
}

class _InvoiceFormScreenState extends ConsumerState<InvoiceFormScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.partyId != null) {
      ref.read(partyRepositoryProvider(widget.kind.partyKind)).watch(widget.partyId!).first.then((p) {
        if (mounted) ref.read(invoiceFormProvider(widget.kind).notifier).setParty(p);
      });
    }
    if (widget.copyFromId != null) _loadCopy(widget.copyFromId!);
  }

  Future<void> _loadCopy(String id) async {
    final source = await ref.read(invoiceRepositoryProvider(widget.kind)).watch(id).first;
    final party = source.partyId == null
        ? null
        : await ref.read(partyRepositoryProvider(widget.kind.partyKind)).watch(source.partyId!).first;
    if (mounted) ref.read(invoiceFormProvider(widget.kind).notifier).loadFrom(source, party);
  }

  Future<void> _save() async {
    final ctrl = ref.read(invoiceFormProvider(widget.kind).notifier);
    final outcome = await runWithFeedback(context, ctrl.submit);
    if (outcome != null && mounted) {
      Toast.success(context, 'تم حفظ ${widget.kind.title} رقم ${outcome.number}');
      context.pushReplacement('${widget.kind.route}/${outcome.postingId}');
    }
  }

  Future<bool> _confirmLeave() async {
    final hasLines = ref.read(invoiceFormProvider(widget.kind)).lines.isNotEmpty;
    if (!hasLines) return true;
    return AppDialog.confirm(
      context,
      title: 'تجاهل الفاتورة؟',
      message: 'لم يتم حفظ الفاتورة بعد. هل تريد الخروج وتجاهل البيانات المدخلة؟',
      confirmLabel: 'خروج بدون حفظ',
      destructive: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.kind;
    final state = ref.watch(invoiceFormProvider(kind));
    final ctrl = ref.read(invoiceFormProvider(kind).notifier);
    // Pre-select the default cashbox once cashboxes are loaded.
    final defaultBox = ref.watch(defaultCashboxProvider);
    if (state.cashbox == null && defaultBox != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ref.read(invoiceFormProvider(kind)).cashbox == null) ctrl.setCashbox(defaultBox);
      });
    }

    final party = AppCard(
      child: PartyPickerField(
        kind: kind.partyKind,
        value: state.party,
        noneLabel: kind.walkInLabel,
        onChanged: ctrl.setParty,
      ),
    );
    final saveButton = PrimaryButton(
      label: 'حفظ الفاتورة',
      icon: Symbols.check,
      onPressed: _save,
      loading: state.saving,
      expand: true,
    );

    final body = context.isDesktop
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [party, const SizedBox(height: 12), InvoiceLinesEditor(kind: kind)],
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 380,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [InvoiceSummaryPanel(kind: kind), const SizedBox(height: 16), saveButton],
                ),
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              party,
              const SizedBox(height: 12),
              InvoiceLinesEditor(kind: kind),
              const SizedBox(height: 12),
              InvoiceSummaryPanel(kind: kind),
            ],
          );

    return PopScope(
      canPop: state.lines.isEmpty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave() && context.mounted) context.pop();
      },
      child: PageScaffold(
        title: 'إنشاء ${kind.title}',
        body: body,
        bottomBar: context.isDesktop
            ? null
            : SafeArea(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('الصافي', style: Theme.of(context).textTheme.bodySmall),
                          MoneyText(state.total, style: Theme.of(context).textTheme.titleMedium),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(child: saveButton),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
