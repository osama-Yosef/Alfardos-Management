import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/accounting/posting.dart';
import '../../../core/firebase/collections.dart';
import '../../../core/utils/dates.dart';
import '../domain/activity.dart';
import '../domain/stats.dart';

class DashboardRepository {
  DashboardRepository(this._db);
  final FirebaseFirestore _db;

  /// Daily statistics in range (≤ 366 small documents for a year).
  Stream<List<DailyStat>> dailyStats(DateRange range) => _db
      .collection(Col.dailyStats)
      .where('dayKey', isGreaterThanOrEqualTo: Dates.dayKey(range.from))
      .where('dayKey', isLessThanOrEqualTo: Dates.dayKey(range.to))
      .snapshots()
      .map((s) => [
            for (final d in s.docs)
              DailyStat(Dates.parseDayKey(d.id), PostingMetrics.fromMap(d.data())),
          ]);

  /// Sum of positive balances (money owed to us / by us).
  Stream<({int total, int count})> outstanding(String collection) => _db
      .collection(collection)
      .where('balance', isGreaterThan: 0)
      .snapshots()
      .map((s) => (
            total: s.docs.fold<int>(0, (a, d) => a + ((d.data()['balance'] as num?)?.toInt() ?? 0)),
            count: s.docs.length,
          ));

  Stream<List<({String id, String name, int balance})>> topBalances(String collection, {int limit = 5}) => _db
      .collection(collection)
      .where('balance', isGreaterThan: 0)
      .orderBy('balance', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => [
            for (final d in s.docs)
              (id: d.id, name: d.data()['name'] as String? ?? '', balance: (d.data()['balance'] as num).toInt()),
          ]);

  Stream<List<Activity>> recentActivity({int limit = 12, List<String>? types}) {
    Query<Map<String, dynamic>> q = _db.collection(Col.financialTransactions);
    if (types != null) q = q.where('type', whereIn: types);
    return q
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(Activity.fromDoc).toList());
  }
}
