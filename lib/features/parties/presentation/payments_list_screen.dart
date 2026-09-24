import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/widgets/live_query_list.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/states.dart';
import '../../auth/application/auth_providers.dart';
import '../application/party_providers.dart';
import '../domain/party.dart';
import '../domain/payment.dart';
import 'payment_tile.dart';

class PaymentsListScreen extends ConsumerWidget {
  const PaymentsListScreen({super.key, required this.kind});

  final PartyKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canPay = ref.watch(canProvider(kind.pay));
    final path = kind.isCustomer ? '/receipts/new' : '/supplier-payments/new';
    final title = kind.isCustomer ? 'التحصيلات من العملاء' : 'المدفوعات للموردين';
    return PageScaffold(
      title: title,
      actions: [
        if (canPay && !context.isMobile)
          FilledButton.icon(
            onPressed: () => context.push(path),
            icon: const Icon(Symbols.add),
            label: Text(kind.paymentTitle),
          ),
      ],
      floatingAction: canPay && context.isMobile
          ? FloatingActionButton(onPressed: () => context.push(path), child: const Icon(Symbols.add))
          : null,
      body: LiveQueryList<Payment>(
        query: ref.watch(partyRepositoryProvider(kind)).paymentsQuery(),
        fromDoc: (d) => Payment.fromDoc(kind, d),
        empty: EmptyState(
          icon: Symbols.payments,
          title: kind.isCustomer ? 'لا توجد تحصيلات حتى الآن' : 'لا توجد مدفوعات حتى الآن',
          actionLabel: canPay ? kind.paymentTitle : null,
          onAction: () => context.push(path),
        ),
        itemBuilder: (_, p, _) => PaymentTile(payment: p),
      ),
    );
  }
}
