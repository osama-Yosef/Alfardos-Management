import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/accounting/invoice_calculator.dart';
import '../../../core/accounting/posting.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/firebase/collections.dart';
import '../../../core/utils/dates.dart';
import '../../cashboxes/domain/cashbox.dart';
import '../../catalog/domain/catalog_item.dart';
import '../../dashboard/domain/stats.dart';
import '../../expenses/domain/expense.dart';
import '../../invoices/domain/invoice.dart';
import '../../parties/domain/party.dart';
import '../domain/report_builders.dart';

/// Loads the raw records behind each report for a date range.
class ReportsRepository {
  ReportsRepository(this._db);
  final FirebaseFirestore _db;

  /// Safety cap per report query; ranges this large should be narrowed.
  static const maxRecords = 5000;

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _range(String col, DateRange r) async {
    final snap = await _db
        .collection(col)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(r.from))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(r.to))
        .orderBy('date', descending: true)
        .limit(maxRecords + 1)
        .get();
    if (snap.docs.length > maxRecords) {
      throw const AppException('الفترة المحددة تحتوي على عدد كبير جداً من السجلات. اختر فترة أقصر.');
    }
    return snap.docs;
  }

  Future<List<DailyStat>> dailyStats(DateRange r) async {
    final snap = await _db
        .collection(Col.dailyStats)
        .where('dayKey', isGreaterThanOrEqualTo: Dates.dayKey(r.from))
        .where('dayKey', isLessThanOrEqualTo: Dates.dayKey(r.to))
        .get();
    return [for (final d in snap.docs) DailyStat(Dates.parseDayKey(d.id), PostingMetrics.fromMap(d.data()))];
  }

  Future<List<Invoice>> invoices(InvoiceKind kind, DateRange r) async =>
      (await _range(kind.collection, r)).map((d) => Invoice.fromDoc(kind, d)).toList();

  Future<List<Expense>> expenses(DateRange r) async =>
      (await _range(Col.expenses, r)).map(Expense.fromDoc).toList();

  Future<List<Party>> partiesWithBalance(PartyKind kind) async {
    final snap = await _db.collection(kind.collection).where('balance', isNotEqualTo: 0).get();
    return snap.docs.map((d) => Party.fromDoc(kind, d)).toList();
  }

  Future<List<Cashbox>> cashboxes() async {
    final snap = await _db.collection(Col.cashboxes).orderBy('name').get();
    return snap.docs.map(Cashbox.fromDoc).toList();
  }

  /// All cash movements dated on/after [from] (needed to roll the current
  /// balance back to the opening balance of the range).
  Future<List<CashMove>> cashMovesSince(DateTime from) async {
    final snap = await _db
        .collection(Col.cashTransactions)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .limit(maxRecords * 4)
        .get();
    return [
      for (final d in snap.docs)
        CashMove(
          cashboxId: d['cashboxId'] as String,
          amount: (d['amount'] as num).toInt(),
          date: (d['date'] as Timestamp).toDate(),
          isTransfer: (d.data()['originalType'] ?? d['type']) == PostingType.transfer.name,
        ),
    ];
  }

  Future<List<SoldItem>> soldItems(DateRange r, {LineKind? kind}) async {
    Query<Map<String, dynamic>> q = _db.collection(Col.saleItems);
    if (kind != null) q = q.where('kind', isEqualTo: kind.name);
    final snap = await q
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(r.from))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(r.to))
        .limit(maxRecords * 4)
        .get();
    return [
      for (final d in snap.docs)
        SoldItem(
          itemId: d['itemId'] as String,
          name: d['name'] as String,
          kind: LineKind.parse(d['kind'] as String),
          quantity: (d['qty'] as num).toDouble(),
          net: (d['net'] as num).toInt(),
          cost: (d['cost'] as num).toInt(),
        ),
    ];
  }

  Future<List<Product>> products() async {
    final snap = await _db.collection(Col.products).orderBy('name').get();
    return snap.docs.map(Product.fromDoc).toList();
  }

  Query<Map<String, dynamic>> journalQuery(DateRange r) => _db
      .collection(Col.financialTransactions)
      .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(r.from))
      .where('date', isLessThanOrEqualTo: Timestamp.fromDate(r.to))
      .orderBy('date', descending: true);
}
