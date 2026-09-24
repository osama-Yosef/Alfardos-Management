import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/accounting/posting_factory.dart';
import '../../../core/accounting/statement.dart';
import '../../../core/accounting/posting.dart';
import '../../../core/audit/audit_entry.dart';
import '../../../core/firebase/collections.dart';
import '../../../core/ledger/ledger_service.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/keywords.dart';
import '../../auth/domain/app_user.dart';
import '../domain/party.dart';
import '../domain/payment.dart';

enum PartyFilter { all, withBalance, inactive }

class PartyRepository {
  PartyRepository(this._db, this.kind);

  final FirebaseFirestore _db;
  final PartyKind kind;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection(kind.collection);

  Query<Map<String, dynamic>> query({String search = '', PartyFilter filter = PartyFilter.all}) {
    Query<Map<String, dynamic>> q = _col;
    final term = Keywords.term(search);
    if (term != null) {
      return q.where('keywords', arrayContains: term).orderBy('name');
    }
    switch (filter) {
      case PartyFilter.withBalance:
        return q.where('balance', isNotEqualTo: 0).orderBy('balance', descending: true);
      case PartyFilter.inactive:
        return q.where('active', isEqualTo: false).orderBy('name');
      case PartyFilter.all:
        return q.orderBy('name');
    }
  }

  Stream<Party> watch(String id) =>
      _col.doc(id).snapshots().map((d) => Party.fromDoc(kind, d));

  Future<List<Party>> search(String text, {int limit = 20}) async {
    final term = Keywords.term(text);
    Query<Map<String, dynamic>> q = _col.where('active', isEqualTo: true);
    q = term == null
        ? q.orderBy('name').limit(limit)
        : q.where('keywords', arrayContains: term).limit(limit);
    final snap = await q.get();
    return snap.docs.map((d) => Party.fromDoc(kind, d)).toList();
  }

  Map<String, dynamic> _data(PartyInput input) => {
        ...input.toMap(),
        'keywords': Keywords.build([input.name, input.phone]),
      };

  /// Creates a party. A non-zero opening balance is posted through the
  /// ledger in the same atomic transaction as the new document.
  Future<String> create(
    PartyInput input, {
    required AppUser user,
    required LedgerService ledger,
    int openingBalance = 0,
    DateTime? openingDate,
  }) async {
    final ref = _col.doc();
    final data = {
      ..._data(input),
      'balance': 0,
      'openingBalance': openingBalance,
      'totalIncrease': 0,
      'totalDecrease': 0,
      'invoiceCount': 0,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': user.uid,
    };
    final audit = AuditEntry(
      action: AuditAction.create,
      entityType: kind.collection,
      entityId: ref.id,
      summary: 'إضافة ${kind.singular}: ${input.name.trim()}',
      after: input.toMap()..['openingBalance'] = openingBalance,
    );

    if (openingBalance == 0) {
      final batch = _db.batch()
        ..set(ref, data)
        ..set(audit.newRef(_db), audit.toMap(uid: user.uid, userName: user.name));
      await batch.commit();
      return ref.id;
    }

    final date = openingDate ?? DateTime.now();
    await ledger.post(PostingRequest(
      postingId: _db.collection(Col.financialTransactions).doc().id,
      build: (_) => PostingDraft(
        posting: kind.isCustomer
            ? PostingFactory.customerOpening(
                customerId: ref.id, customerName: input.name.trim(), date: date, amount: openingBalance)
            : PostingFactory.supplierOpening(
                supplierId: ref.id, supplierName: input.name.trim(), date: date, amount: openingBalance),
        newAccounts: {ref.path: data},
        audit: audit,
      ),
    ));
    return ref.id;
  }

  Future<void> update(Party before, PartyInput input, AppUser user) async {
    final batch = _db.batch()
      ..update(_col.doc(before.id), {
        ..._data(input),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': user.uid,
      });
    final audit = AuditEntry(
      action: AuditAction.update,
      entityType: kind.collection,
      entityId: before.id,
      summary: 'تعديل بيانات ${kind.singular}: ${input.name.trim()}',
      before: {'name': before.name, 'phone': before.phone, 'address': before.address, 'notes': before.notes},
      after: input.toMap(),
    );
    batch.set(audit.newRef(_db), audit.toMap(uid: user.uid, userName: user.name));
    await batch.commit();
  }

  /// Parties are never deleted (they own financial history); they are
  /// deactivated so they disappear from pickers.
  Future<void> setActive(Party party, bool active, AppUser user) async {
    final batch = _db.batch()
      ..update(_col.doc(party.id), {
        'active': active,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': user.uid,
      });
    final audit = AuditEntry(
      action: active ? AuditAction.activate : AuditAction.deactivate,
      entityType: kind.collection,
      entityId: party.id,
      summary: '${active ? 'تفعيل' : 'إيقاف'} ${kind.singular}: ${party.name}',
    );
    batch.set(audit.newRef(_db), audit.toMap(uid: user.uid, userName: user.name));
    await batch.commit();
  }

  /// Statement derived from the sub-ledger records (never from the stored
  /// balance): opening = Σ movements before [range], then running balance.
  Future<Statement> statement(String partyId, DateRange range) async {
    final snap = await _db
        .collection(kind.txCollection)
        .where(kind.idField, isEqualTo: partyId)
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(range.to))
        .orderBy('date')
        .get();
    var opening = 0;
    final entries = <StatementEntry>[];
    for (final d in snap.docs) {
      final m = d.data();
      final date = (m['date'] as Timestamp).toDate();
      final inc = (m['increase'] as num?)?.toInt() ?? 0;
      final dec = (m['decrease'] as num?)?.toInt() ?? 0;
      if (date.isBefore(range.from)) {
        opening += inc - dec;
        continue;
      }
      final type = PostingType.parse(m['type'] as String);
      entries.add(StatementEntry(
        id: d.id,
        date: date,
        description: m['description'] as String? ?? '',
        increase: inc,
        decrease: dec,
        reference: m['sourceNumber'] as String?,
        typeLabel: type.label,
      ));
    }
    return Statement.build(opening: opening, entries: entries);
  }

  // ---------------------------------------------------------------- payments

  Query<Map<String, dynamic>> paymentsQuery({String? partyId}) {
    Query<Map<String, dynamic>> q = _db.collection(kind.paymentCollection);
    if (partyId != null) q = q.where('partyId', isEqualTo: partyId);
    return q.orderBy('date', descending: true);
  }

  /// Records a customer receipt or supplier payment through the ledger.
  Future<PostingOutcome> recordPayment({
    required String postingId,
    required Party party,
    required String cashboxId,
    required String cashboxName,
    required int amount,
    required DateTime date,
    required PaymentMethod method,
    required String notes,
    required LedgerService ledger,
  }) {
    final ref = _db.collection(kind.paymentCollection).doc(postingId);
    return ledger.post(PostingRequest(
      postingId: postingId,
      counter: kind.isCustomer ? Counter.customerPayments : Counter.supplierPayments,
      build: (ctx) {
        final number = ctx.number!;
        final posting = kind.isCustomer
            ? PostingFactory.customerPayment(
                paymentId: ref.id, number: number, date: date, customerId: party.id,
                customerName: party.name, cashboxId: cashboxId, amount: amount, notes: notes)
            : PostingFactory.supplierPayment(
                paymentId: ref.id, number: number, date: date, supplierId: party.id,
                supplierName: party.name, cashboxId: cashboxId, amount: amount, notes: notes);
        return PostingDraft(
          posting: posting,
          documents: [
            DocWrite.set(ref, {
              'number': number,
              'date': Timestamp.fromDate(date),
              'dayKey': Dates.dayKey(date),
              'partyId': party.id,
              'partyName': party.name,
              kind.idField: party.id,
              'cashboxId': cashboxId,
              'cashboxName': cashboxName,
              'amount': amount,
              'method': method.name,
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
            entityType: kind.paymentCollection,
            entityId: ref.id,
            summary: '${kind.paymentTitle} ${party.name} - سند $number',
            after: {'amount': amount, 'cashbox': cashboxName, 'method': method.label},
          ),
        );
      },
    ));
  }

  Future<void> cancelPayment(Payment payment, String reason, LedgerService ledger) {
    return ledger.cancel(
      sourceRef: _db.collection(kind.paymentCollection).doc(payment.id),
      reason: reason,
      audit: (_) => AuditEntry(
        action: AuditAction.cancel,
        entityType: kind.paymentCollection,
        entityId: payment.id,
        summary: 'إلغاء سند ${payment.number} (${payment.partyName}) - $reason',
        before: {'amount': payment.amount, 'status': 'active'},
        after: {'status': 'cancelled'},
      ),
    );
  }
}
