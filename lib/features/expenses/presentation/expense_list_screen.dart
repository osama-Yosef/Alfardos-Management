import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../../core/permissions/permissions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/fields.dart';
import '../../../core/widgets/live_query_list.dart';
import '../../../core/widgets/money_text.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/period_selector.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/application/auth_providers.dart';
import '../application/expense_providers.dart';
import '../domain/expense.dart';

class ExpenseListScreen extends ConsumerStatefulWidget {
  const ExpenseListScreen({super.key});

  @override
  ConsumerState<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends ConsumerState<ExpenseListScreen> {
  String _search = '';
  ExpenseCategory? _category;
  Period _period = Period.of(PeriodPreset.month);

  Future<void> _cancel(Expense e) async {
    final reason = await AppDialog.cancelReason(
      context,
      title: 'إلغاء المصروف ${e.number}',
      message: 'سيُسجل قيد عكسي يعيد المبلغ إلى "${e.cashboxName}" ويُستبعد من الأرباح.',
    );
    if (reason == null || !mounted) return;
    await runWithFeedback(
      context,
      () => ref.read(expenseRepositoryProvider).cancel(e, reason, ref.read(ledgerProvider)),
      success: 'تم إلغاء المصروف',
    );
  }

  @override
  Widget build(BuildContext context) {
    final canCreate = ref.watch(canProvider(Permission.createExpense));
    final canCancel = ref.watch(canProvider(Permission.cancelPayments));
    final canManageCats = ref.watch(canProvider(Permission.manageExpenseCategories));
    final categories = ref.watch(expenseCategoriesProvider).value ?? const [];
    final query = ref.watch(expenseRepositoryProvider).query(
          search: _search,
          categoryId: _category?.id,
          range: _period.range,
        );

    return PageScaffold(
      title: 'المصروفات',
      actions: [
        if (canManageCats && !context.isMobile)
          OutlinedButton.icon(
            onPressed: () => context.push('/expenses/categories'),
            icon: const Icon(Symbols.category),
            label: const Text('البنود'),
          ),
        if (canCreate && !context.isMobile)
          FilledButton.icon(
            onPressed: () => context.push('/expenses/new'),
            icon: const Icon(Symbols.add),
            label: const Text('إضافة مصروف'),
          ),
        if (canManageCats && context.isMobile)
          IconButton(onPressed: () => context.push('/expenses/categories'), icon: const Icon(Symbols.category)),
      ],
      floatingAction: canCreate && context.isMobile
          ? FloatingActionButton(onPressed: () => context.push('/expenses/new'), child: const Icon(Symbols.add))
          : null,
      body: ListPageBody(
        toolbar: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PeriodSelector(value: _period, onChanged: (p) => setState(() => _period = p)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: context.isMobile ? double.infinity : 320,
                  child: SearchField(onChanged: (v) => setState(() => _search = v), hint: 'بحث في المصروفات...'),
                ),
                SizedBox(
                  width: context.isMobile ? double.infinity : 240,
                  child: AppDropdown<ExpenseCategory?>(
                    label: 'البند',
                    items: [null, ...categories],
                    value: _category,
                    itemLabel: (c) => c?.name ?? 'كل البنود',
                    onChanged: (c) => setState(() => _category = c),
                  ),
                ),
              ],
            ),
          ],
        ),
        child: LiveQueryList<Expense>(
          query: query,
          fromDoc: Expense.fromDoc,
          empty: EmptyState(
            icon: Symbols.payments,
            title: 'لا توجد مصروفات في هذه الفترة',
            actionLabel: canCreate ? 'إضافة مصروف' : null,
            onAction: () => context.push('/expenses/new'),
          ),
          itemBuilder: (context, e, _) => ListTile(
            leading: CircleAvatar(
              backgroundColor: e.cancelled ? AppColors.neutralSoft : AppColors.dangerSoft,
              child: Icon(Symbols.payments, size: 20, color: e.cancelled ? AppColors.neutral : AppColors.danger),
            ),
            title: Row(children: [
              Flexible(child: Text(e.categoryName, overflow: TextOverflow.ellipsis)),
              if (e.cancelled) ...[const SizedBox(width: 8), const StatusBadge('ملغى')],
            ]),
            subtitle: Text(
              [e.number, Dates.format(e.date), e.cashboxName, if (e.description.isNotEmpty) e.description].join(' • '),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (e.attachmentUrl != null)
                  IconButton(
                    tooltip: 'عرض المرفق',
                    icon: const Icon(Symbols.attach_file, size: 20),
                    onPressed: () => launchUrl(Uri.parse(e.attachmentUrl!)),
                  ),
                MoneyText(
                  e.amount,
                  tone: e.cancelled ? Tone.neutral : Tone.danger,
                  style: TextStyle(fontWeight: FontWeight.w600, decoration: e.cancelled ? TextDecoration.lineThrough : null),
                ),
                if (canCancel && !e.cancelled)
                  PopupMenuButton<String>(
                    onSelected: (_) => _cancel(e),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'cancel', child: Text('إلغاء المصروف', style: TextStyle(color: AppColors.danger))),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
