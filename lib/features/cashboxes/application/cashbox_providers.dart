import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accounting/statement.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/utils/dates.dart';
import '../../settings/application/settings_providers.dart';
import '../data/cashbox_repository.dart';
import '../domain/cashbox.dart';

final cashboxRepositoryProvider =
    Provider<CashboxRepository>((ref) => CashboxRepository(ref.watch(firestoreProvider)));

final cashboxesProvider = StreamProvider<List<Cashbox>>(
  (ref) => ref.watch(cashboxRepositoryProvider).watchAll(),
);

final activeCashboxesProvider = Provider<List<Cashbox>>((ref) {
  final all = ref.watch(cashboxesProvider).value ?? const [];
  return all.where((c) => c.active).toList();
});

/// The company's default cashbox, or the first active one.
final defaultCashboxProvider = Provider<Cashbox?>((ref) {
  final active = ref.watch(activeCashboxesProvider);
  if (active.isEmpty) return null;
  final id = ref.watch(companySettingsProvider).defaultCashboxId;
  return active.firstWhere((c) => c.id == id, orElse: () => active.first);
});

final cashboxProvider = StreamProvider.autoDispose.family<Cashbox, String>(
  (ref, id) => ref.watch(cashboxRepositoryProvider).watch(id),
);

final cashboxStatementProvider =
    FutureProvider.autoDispose.family<Statement, (String, DateRange)>((ref, key) {
  ref.watch(cashboxProvider(key.$1).select((c) => c.value?.balance));
  return ref.watch(cashboxRepositoryProvider).statement(key.$1, key.$2);
});

/// Total of all cashbox balances (inactive boxes still hold money).
final totalCashProvider = Provider<int>((ref) {
  final all = ref.watch(cashboxesProvider).value ?? const [];
  return all.fold(0, (s, c) => s + c.balance);
});
