import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/utils/validators.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/fields.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/application/auth_providers.dart';
import '../application/expense_providers.dart';
import '../domain/expense.dart';

class ExpenseCategoriesScreen extends ConsumerWidget {
  const ExpenseCategoriesScreen({super.key});

  Future<String?> _askName(BuildContext context, {String? initial}) {
    final controller = TextEditingController(text: initial);
    final form = GlobalKey<FormState>();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(initial == null ? 'بند مصروفات جديد' : 'تعديل البند'),
        content: SizedBox(
          width: 380,
          child: Form(
            key: form,
            child: AppTextField(
              label: 'اسم البند',
              controller: controller,
              autofocus: true,
              validator: (v) => Validators.required(v, 'اسم البند'),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(ctx, controller.text.trim());
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(expenseCategoriesProvider);
    final repo = ref.watch(expenseRepositoryProvider);
    final user = ref.watch(currentUserProvider)!;

    Future<void> add(int count) async {
      final name = await _askName(context);
      if (name == null || !context.mounted) return;
      await runWithFeedback(context, () => repo.addCategory(name, count, user), success: 'تمت الإضافة');
    }

    return PageScaffold(
      title: 'بنود المصروفات',
      maxWidth: 720,
      actions: [
        FilledButton.icon(
          onPressed: () => add(categories.value?.length ?? 0),
          icon: const Icon(Symbols.add),
          label: const Text('بند جديد'),
        ),
      ],
      body: AsyncView<List<ExpenseCategory>>(
        value: categories,
        data: (list) => list.isEmpty
            ? Card(
                child: EmptyState(
                  icon: Symbols.category,
                  title: 'لا توجد بنود',
                  actionLabel: 'بند جديد',
                  onAction: () => add(0),
                ),
              )
            : Card(
                child: Column(
                  children: [
                    for (var i = 0; i < list.length; i++) ...[
                      if (i > 0) const Divider(),
                      ListTile(
                        leading: const Icon(Symbols.label),
                        title: Text(list[i].name),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            StatusBadge.active(list[i].active),
                            IconButton(
                              tooltip: 'تعديل',
                              icon: const Icon(Symbols.edit, size: 20),
                              onPressed: () async {
                                final name = await _askName(context, initial: list[i].name);
                                if (name == null || !context.mounted) return;
                                await runWithFeedback(context,
                                    () => repo.updateCategory(list[i], name: name, user: user), success: 'تم الحفظ');
                              },
                            ),
                            Switch(
                              value: list[i].active,
                              onChanged: (v) => runWithFeedback(
                                  context, () => repo.updateCategory(list[i], active: v, user: user)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}
