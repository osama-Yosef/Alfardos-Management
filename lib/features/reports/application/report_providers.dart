import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accounting/invoice_calculator.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/permissions/permissions.dart';
import '../../../core/utils/dates.dart';
import '../../auth/application/auth_providers.dart';
import '../../invoices/domain/invoice.dart';
import '../../parties/domain/party.dart';
import '../data/reports_repository.dart';
import '../domain/report_builders.dart';
import '../domain/report_data.dart';
import '../domain/report_type.dart';

final reportsRepositoryProvider = Provider((ref) => ReportsRepository(ref.watch(firestoreProvider)));

/// Loads and computes a report. Re-runs when the type or range changes.
final reportProvider = FutureProvider.autoDispose.family<ReportData, (ReportType, DateRange)>((ref, key) async {
  final repo = ref.watch(reportsRepositoryProvider);
  final showCost = ref.watch(canProvider(Permission.viewCost));
  final (type, range) = key;
  return switch (type) {
    ReportType.profit => ReportBuilders.profit(await repo.dailyStats(range), range),
    ReportType.sales => ReportBuilders.sales(await repo.invoices(InvoiceKind.sale, range), showCost: showCost),
    ReportType.purchases => ReportBuilders.purchases(await repo.invoices(InvoiceKind.purchase, range)),
    ReportType.expenses => ReportBuilders.expenses(await repo.expenses(range)),
    ReportType.customerDebts => ReportBuilders.balances(await repo.partiesWithBalance(PartyKind.customer), PartyKind.customer),
    ReportType.supplierPayables => ReportBuilders.balances(await repo.partiesWithBalance(PartyKind.supplier), PartyKind.supplier),
    ReportType.cashboxes => ReportBuilders.cashboxes(await repo.cashboxes(), await repo.cashMovesSince(range.from), range),
    ReportType.services => ReportBuilders.services(await repo.soldItems(range, kind: LineKind.service)),
    ReportType.products => ReportBuilders.products(await repo.products()),
    ReportType.journal => throw UnsupportedError('Journal is a live list'),
  };
});
