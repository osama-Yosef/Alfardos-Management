import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accounting/posting.dart';
import '../../../core/firebase/collections.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/period_selector.dart';
import '../data/dashboard_repository.dart';
import '../domain/activity.dart';
import '../domain/stats.dart';

final dashboardRepositoryProvider =
    Provider((ref) => DashboardRepository(ref.watch(firestoreProvider)));

class DashboardPeriod extends Notifier<Period> {
  @override
  Period build() => Period.of(PeriodPreset.month);

  void set(Period p) => state = p;
}

final dashboardPeriodProvider = NotifierProvider<DashboardPeriod, Period>(DashboardPeriod.new);

final dailyStatsProvider = StreamProvider.autoDispose.family<List<DailyStat>, DateRange>(
  (ref, range) => ref.watch(dashboardRepositoryProvider).dailyStats(range),
);

/// Month-to-date stats; today's figures are derived from the same stream.
final monthStatsProvider = Provider.autoDispose<AsyncValue<({PostingMetrics today, PostingMetrics month})>>((ref) {
  final range = PeriodPreset.month.range();
  return ref.watch(dailyStatsProvider(range)).whenData((stats) => (
        today: StatsMath.total(stats, PeriodPreset.today.range()),
        month: StatsMath.total(stats),
      ));
});

final receivablesProvider = StreamProvider.autoDispose(
  (ref) => ref.watch(dashboardRepositoryProvider).outstanding(Col.customers),
);

final payablesProvider = StreamProvider.autoDispose(
  (ref) => ref.watch(dashboardRepositoryProvider).outstanding(Col.suppliers),
);

final topDebtorsProvider = StreamProvider.autoDispose(
  (ref) => ref.watch(dashboardRepositoryProvider).topBalances(Col.customers),
);

final topPayablesProvider = StreamProvider.autoDispose(
  (ref) => ref.watch(dashboardRepositoryProvider).topBalances(Col.suppliers),
);

final recentActivityProvider = StreamProvider.autoDispose<List<Activity>>(
  (ref) => ref.watch(dashboardRepositoryProvider).recentActivity(),
);
