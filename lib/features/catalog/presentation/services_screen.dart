import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

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
import '../application/catalog_providers.dart';
import '../data/catalog_repository.dart';
import '../domain/catalog_item.dart';

class ServicesScreen extends ConsumerStatefulWidget {
  const ServicesScreen({super.key});

  @override
  ConsumerState<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends ConsumerState<ServicesScreen> {
  String _search = '';
  bool _inactive = false;

  @override
  Widget build(BuildContext context) {
    final canManage = ref.watch(canProvider(Permission.manageCatalog));
    final canCost = ref.watch(canProvider(Permission.viewCost));
    final canReports = ref.watch(canProvider(Permission.viewReports));
    void add() => _showServiceForm(context);

    return PageScaffold(
      title: 'الخدمات',
      actions: [
        if (canReports)
          OutlinedButton.icon(
            onPressed: () => context.push('/reports/services'),
            icon: const Icon(Symbols.monitoring),
            label: const Text('تقرير الخدمات'),
          ),
        if (canManage && !context.isMobile)
          FilledButton.icon(onPressed: add, icon: const Icon(Symbols.add), label: const Text('إضافة خدمة')),
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
              child: SearchField(onChanged: (v) => setState(() => _search = v), hint: 'ابحث عن خدمة...'),
            ),
            FilterChip(
              label: const Text('الموقوفة فقط'),
              selected: _inactive,
              onSelected: (v) => setState(() => _inactive = v),
            ),
          ],
        ),
        child: LiveQueryList<ServiceItem>(
          query: ref.watch(catalogRepositoryProvider).servicesQuery(search: _search, inactive: _inactive),
          fromDoc: ServiceItem.fromDoc,
          empty: EmptyState(
            icon: Symbols.home_repair_service,
            title: 'لا توجد خدمات حتى الآن',
            message: 'أضف خدماتك (مثل التركيب أو الصيانة) بسعر البيع والتكلفة لحساب ربحها تلقائياً.',
            actionLabel: canManage ? 'إضافة خدمة' : null,
            onAction: add,
          ),
          itemBuilder: (context, s, _) => ListTile(
            onTap: canManage ? () => _showServiceForm(context, service: s) : null,
            leading: const CircleAvatar(
              backgroundColor: AppColors.infoSoft,
              child: Icon(Symbols.home_repair_service, color: AppColors.info, size: 20),
            ),
            title: Row(children: [
              Flexible(child: Text(s.name, overflow: TextOverflow.ellipsis)),
              if (!s.active) ...[const SizedBox(width: 8), StatusBadge.active(false)],
            ]),
            subtitle: canCost
                ? Row(children: [
                    const Text('التكلفة: '),
                    MoneyText(s.cost),
                    const Text('  •  الربح: '),
                    MoneyText(s.profit, autoTone: true),
                    Text('  (${(s.margin * 100).toStringAsFixed(0)}%)'),
                  ])
                : (s.description.isEmpty ? null : Text(s.description)),
            trailing: MoneyText(s.sellPrice, style: Theme.of(context).textTheme.titleSmall),
          ),
        ),
      ),
    );
  }
}

Future<void> _showServiceForm(BuildContext context, {ServiceItem? service}) {
  return AppDialog.show(
    context,
    title: service == null ? 'إضافة خدمة' : 'تعديل ${service.name}',
    child: _ServiceForm(service: service),
  );
}

class _ServiceForm extends ConsumerStatefulWidget {
  const _ServiceForm({this.service});
  final ServiceItem? service;

  @override
  ConsumerState<_ServiceForm> createState() => _ServiceFormState();
}

class _ServiceFormState extends ConsumerState<_ServiceForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.service?.name);
  late final _price = TextEditingController(text: widget.service == null ? '' : Money.toInput(widget.service!.sellPrice));
  late final _cost = TextEditingController(text: widget.service == null ? '' : Money.toInput(widget.service!.cost));
  late final _description = TextEditingController(text: widget.service?.description);
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _price, _cost, _description]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final repo = ref.read(catalogRepositoryProvider);
    final user = ref.read(currentUserProvider)!;
    final input = ServiceInput(
      name: _name.text,
      sellPrice: Money.parse(_price.text) ?? 0,
      cost: Money.parse(_cost.text) ?? 0,
      description: _description.text,
    );
    final ok = await runWithFeedback(context, () async {
      if (widget.service == null) {
        await repo.createService(input, user);
      } else {
        await repo.updateService(widget.service!, input, user);
      }
      return true;
    }, success: 'تم الحفظ');
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok == true) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final price = Money.parse(_price.text) ?? 0;
    final cost = Money.parse(_cost.text) ?? 0;
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(label: 'اسم الخدمة', controller: _name, autofocus: widget.service == null,
              validator: (v) => Validators.required(v, 'اسم الخدمة')),
          const SizedBox(height: 14),
          AmountField(label: 'سعر البيع', controller: _price, allowZero: true, onChanged: (_) => setState(() {})),
          const SizedBox(height: 14),
          AmountField(
            label: 'التكلفة',
            controller: _cost,
            allowZero: true,
            helper: 'التكلفة الفعلية لتقديم الخدمة (عمالة، مواد...)',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          Row(children: [
            const Text('الربح المتوقع: '),
            MoneyText(price - cost, autoTone: true, style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 14),
          AppTextField(label: 'الوصف', controller: _description, maxLines: 2),
          const SizedBox(height: 20),
          PrimaryButton(label: 'حفظ', icon: Symbols.save, onPressed: _save, loading: _saving, expand: true),
          if (widget.service != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () async {
                final s = widget.service!;
                await runWithFeedback(
                  context,
                  () => ref.read(catalogRepositoryProvider).setServiceActive(s, !s.active, ref.read(currentUserProvider)!),
                  success: 'تم الحفظ',
                );
                if (context.mounted) Navigator.pop(context);
              },
              child: Text(widget.service!.active ? 'إيقاف الخدمة' : 'تفعيل الخدمة'),
            ),
          ],
        ],
      ),
    );
  }
}
