import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/accounting/posting.dart';
import '../../../core/accounting/posting_factory.dart';
import '../../../core/accounting/statement.dart';
import '../../../core/audit/audit_entry.dart';
import '../../../core/firebase/collections.dart';
import '../../../core/ledger/ledger_service.dart';
import '../../../core/utils/dates.dart';
import '../../auth/domain/app_user.dart';
import '../domain/cashbox.dart';

class CashboxRepository {
  CashboxRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection(Col.cashboxes);

  /// Cashboxes are few; the whole collection is watched live.
  Stream<List<Cashbox>> watchAll() => _col
      .orderBy('name')
      .snapshots()
      .map((s) => s.docs.map(Cashbox.fromDoc).toList());

  Stream<Cashbox> watch(String id) => _col.doc(id).snapshots().map(Cashbox.fromDoc);

  Future<String> create({
    required String name,
    required CashboxKind kind,
    required String notes,
    required int openingBalance,
    required AppUser user,
    required LedgerService ledger,
  }) async {
    final ref = _col.doc();
    final data = {
      'name': name.trim(),
      'kind': kind.name,
      'notes': notes.trim(),
      'balance': 0,
      'totalIn': 0,
      'totalOut': 0,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': user.uid,
    };
    final audit = AuditEntry(
      action: AuditAction.create,
      entityType: Col.cashboxes,
      entityId: ref.id,
      summary: 'إضافة خزنة: ${name.trim()}',
      after: {'name': name.trim(), 'kind': kind.label, 'openingBalance': openingBalance},
    );
    if (openingBalance == 0) {
      final batch = _db.batch()
        ..set(ref, data)
        ..set(audit.newRef(_db), audit.toMap(uid: user.uid, userName: user.name));
      await batch.commit();
      return ref.id;
    }
    await ledger.post(PostingRequest(
      postingId: _db.collection(Col.financialTransactions).doc().id,
      build: (_) => PostingDraft(
        posting: PostingFactory.cashboxOpening(
          cashboxId: ref.id,
          cashboxName: name.trim(),
          date: DateTime.now(),
          amount: openingBalance,
        ),
        newAccounts: {ref.path: data},
        audit: audit,
      ),
    ));
    return ref.id;
  }

  Future<void> update(Cashbox before, {required String name, required CashboxKind kind, required String notes, required AppUser user}) async {
    final batch = _db.batch()
      ..update(_col.doc(before.id), {
        'name': name.trim(),
        'kind': kind.name,
        'notes': notes.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': user.uid,
      });
    final audit = AuditEntry(
      action: AuditAction.update,
      entityType: Col.cashboxes,
      entityId: before.id,
      summary: 'تعديل خزنة: ${name.trim()}',
      before: {'name': before.name, 'kind': before.kind.name, 'notes': before.notes},
      after: {'name': name.trim(), 'kind': kind.name, 'notes': notes.trim()},
    );
    batch.set(audit.newRef(_db), audit.toMap(uid: user.uid, userName: user.name));
    await batch.commit();
  }

  Future<void> setActive(Cashbox box, bool active, AppUser user) async {
    final batch = _db.batch()
      ..update(_col.doc(box.id), {
        'active': active,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': user.uid,
      });
    final audit = AuditEntry(
      action: active ? AuditAction.activate : AuditAction.deactivate,
      entityType: Col.cashboxes,
      entityId: box.id,
      summary: '${active ? 'تفعيل' : 'إيقاف'} خزنة: ${box.name}',
    );
    batch.set(audit.newRef(_db), audit.toMap(uid: user.uid, userName: user.name));
    await batch.commit();
  }

  /// Statement derived from cash transactions: opening, income, expense,
  /// running balance.
  Future<Statement> statement(String cashboxId, DateRange range) async {
    final snap = await _db
        .collection(Col.cashTransactions)
        .where('cashboxId', isEqualTo: cashboxId)
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(range.to))
        .orderBy('date')
        .get();
    var opening = 0;
    final entries = <StatementEntry>[];
    for (final d in snap.docs) {
      final m = d.data();
      final date = (m['date'] as Timestamp).toDate();
      final amount = (m['amount'] as num).toInt();
      if (date.isBefore(range.from)) {
        opening += amount;
        continue;
      }
      final type = PostingType.parse(m['type'] as String);
      final original = m['originalType'] == null ? null : PostingType.parse(m['originalType'] as String);
      entries.add(StatementEntry(
        id: d.id,
        date: date,
        description: m['description'] as String? ?? '',
        increase: amount > 0 ? amount : 0,
        decrease: amount < 0 ? -amount : 0,
        reference: m['sourceNumber'] as String?,
        typeLabel: original == null ? type.label : '${type.label} (${original.label})',
      ));
    }
    return Statement.build(opening: opening, entries: entries);
  }

  // --------------------------------------------------------------- transfers

  Query<Map<String, dynamic>> transfersQuery() =>
      _db.collection(Col.transfers).orderBy('date', descending: true);

  Future<PostingOutcome> transfer({
    required String postingId,
    required Cashbox from,
    required Cashbox to,
    required int amount,
    required DateTime date,
    required String notes,
    required LedgerService ledger,
  }) {
    final ref = _db.collection(Col.transfers).doc(postingId);
    return ledger.post(PostingRequest(
      postingId: postingId,
      counter: Counter.transfers,
      build: (ctx) {
        final number = ctx.number!;
        return PostingDraft(
          posting: PostingFactory.transfer(
            transferId: ref.id,
            number: number,
            date: date,
            fromCashboxId: from.id,
            fromName: from.name,
            toCashboxId: to.id,
            toName: to.name,
            amount: amount,
            notes: notes,
          ),
          documents: [
            DocWrite.set(ref, {
              'number': number,
              'date': Timestamp.fromDate(date),
              'dayKey': Dates.dayKey(date),
              'fromId': from.id,
              'fromName': from.name,
              'toId': to.id,
              'toName': to.name,
              'amount': amount,
              'notes': notes.trim(),
              'status': 'active',
              'financialTxId': postingId,
              'createdAt': FieldValue.serverTimestamp(),
              'createdBy': ctx.actor.uid,
              'createdByName': ctx.actor.name,
            }),
          ],
          audit: AuditEntry(
            action: AuditAction.create,
            entityType: Col.transfers,
            entityId: ref.id,
            summary: 'تحويل $number من ${from.name} إلى ${to.name}',
            after: {'amount': amount},
          ),
        );
      },
    ));
  }

  Future<void> cancelTransfer(Transfer t, String reason, LedgerService ledger) {
    return ledger.cancel(
      sourceRef: _db.collection(Col.transfers).doc(t.id),
      reason: reason,
      audit: (_) => AuditEntry(
        action: AuditAction.cancel,
        entityType: Col.transfers,
        entityId: t.id,
        summary: 'إلغاء التحويل ${t.number} - $reason',
        before: {'amount': t.amount, 'status': 'active'},
        after: {'status': 'cancelled'},
      ),
    );
  }
}
