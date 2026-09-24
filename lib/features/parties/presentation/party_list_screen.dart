import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/module_colors.dart';
import '../../../core/widgets/fields.dart';
import '../../../core/widgets/live_query_list.dart';
import '../../../core/widgets/money_text.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/application/auth_providers.dart';
import '../application/party_providers.dart';
import '../data/party_repository.dart';
import '../domain/party.dart';
import 'party_form.dart';

class PartyListScreen extends ConsumerStatefulWidget {
  const PartyListScreen({super.key, required this.kind});

  final PartyKind kind;

  @override
  ConsumerState<PartyListScreen> createState() => _PartyListScreenState();
}

class _PartyListScreenState extends ConsumerState<PartyListScreen> {
  String _search = '';
  PartyFilter _filter = PartyFilter.all;

  Future<void> _add() async {
    final id = await showPartyForm(context, widget.kind);
    if (id != null && mounted) context.push('${widget.kind.route}/$id');
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.kind;
    final canManage = ref.watch(canProvider(kind.manage));
    final repo = ref.watch(partyRepositoryProvider(kind));
    final query = repo.query(search: _search, filter: _filter);

    final filters = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final f in PartyFilter.values)
          ChoiceChip(
            showCheckmark: false,
            selected: _filter == f,
            label: Text(switch (f) {
              PartyFilter.all => 'الكل',
              PartyFilter.withBalance => kind.isCustomer ? 'عليهم رصيد' : 'لهم رصيد',
              PartyFilter.inactive => 'موقوف',
            }),
            onSelected: (_) => setState(() => _filter = f),
          ),
      ],
    );

    return PageScaffold(
      title: kind.plural,
      actions: [
        if (canManage && !context.isMobile)
          FilledButton.icon(onPressed: _add, icon: const Icon(Symbols.person_add), label: Text('إضافة ${kind.singular}')),
      ],
      floatingAction: canManage && context.isMobile
          ? FloatingActionButton(onPressed: _add, tooltip: 'إضافة ${kind.singular}', child: const Icon(Symbols.person_add))
          : null,
      body: ListPageBody(
        toolbar: context.isMobile
            ? Column(children: [
                SearchField(onChanged: (v) => setState(() => _search = v), hint: 'ابحث بالاسم أو الهاتف...'),
                const SizedBox(height: 10),
                Align(alignment: AlignmentDirectional.centerStart, child: filters),
              ])
            : Row(children: [
                SizedBox(width: 340, child: SearchField(onChanged: (v) => setState(() => _search = v), hint: 'ابحث بالاسم أو الهاتف...')),
                const SizedBox(width: 16),
                Expanded(child: filters),
              ]),
        child: LiveQueryList<Party>(
          query: query,
          fromDoc: (d) => Party.fromDoc(kind, d),
          empty: EmptyState(
            icon: kind.isCustomer ? Symbols.groups : Symbols.local_shipping,
            title: _search.isEmpty
                ? (kind.isCustomer ? 'لا يوجد عملاء حتى الآن' : 'لا يوجد موردون حتى الآن')
                : 'لا توجد نتائج مطابقة',
            message: _search.isEmpty ? 'أضف أول ${kind.singular} لبدء تسجيل الفواتير والمدفوعات.' : null,
            actionLabel: canManage && _search.isEmpty ? 'إضافة ${kind.singular}' : null,
            onAction: _add,
          ),
          itemBuilder: (context, p, meta) => _PartyTile(party: p, pending: meta.hasPendingWrites),
        ),
      ),
    );
  }
}

class _PartyTile extends StatelessWidget {
  const _PartyTile({required this.party, required this.pending});

  final Party party;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tone = party.balance > 0
        ? (party.kind.isCustomer ? Tone.danger : Tone.warning)
        : (party.balance < 0 ? Tone.info : Tone.neutral);
    return ListTile(
      onTap: () => context.push('${party.kind.route}/${party.id}'),
      leading: CircleAvatar(
        backgroundColor: ModuleColors.soft(party.kind.isCustomer ? ModuleColors.customers : ModuleColors.suppliers),
        child: Text(party.name.isEmpty ? '?' : party.name.characters.first,
            style: TextStyle(
                color: party.kind.isCustomer ? ModuleColors.customers : ModuleColors.suppliers,
                fontWeight: FontWeight.w700)),
      ),
      title: Row(
        children: [
          Flexible(child: Text(party.name, overflow: TextOverflow.ellipsis)),
          if (!party.active) ...[const SizedBox(width: 8), StatusBadge.active(false)],
          if (pending) ...[
            const SizedBox(width: 8),
            const StatusBadge('قيد المزامنة', tone: Tone.warning, icon: Symbols.sync),
          ],
        ],
      ),
      subtitle: Text(
        [if (party.phone.isNotEmpty) party.phone, '${party.invoiceCount} فاتورة'].join(' • '),
        style: t.bodySmall,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          MoneyText(party.balance, tone: tone, style: t.titleSmall),
          Text(party.balance == 0 ? 'لا يوجد رصيد' : (party.balance > 0 ? 'مستحق' : 'رصيد دائن'), style: t.bodySmall),
        ],
      ),
    );
  }
}
