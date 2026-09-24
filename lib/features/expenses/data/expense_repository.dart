import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../core/accounting/posting_factory.dart';
import '../../../core/audit/audit_entry.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/firebase/collections.dart';
import '../../../core/ledger/ledger_service.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/keywords.dart';
import '../../auth/domain/app_user.dart';
import '../../cashboxes/domain/cashbox.dart';
import '../domain/expense.dart';

class ExpenseRepository {
  ExpenseRepository(this._db, this._storage);

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection(Col.expenses);
  CollectionReference<Map<String, dynamic>> get _categories => _db.collection(Col.expenseCategories);

  Stream<List<ExpenseCategory>> watchCategories() => _categories
      .orderBy('order')
      .snapshots()
      .map((s) => s.docs.map(ExpenseCategory.fromDoc).toList());

  Future<void> addCategory(String name, int order, AppUser user) async {
    final ref = _categories.doc();
    final audit = AuditEntry(
      action: AuditAction.create,
      entityType: Col.expenseCategories,
      entityId: ref.id,
      summary: 'إضافة بند مصروفات: ${name.trim()}',
    );
    final batch = _db.batch()
      ..set(ref, {
        'name': name.trim(),
        'active': true,
        'order': order,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': user.uid,
      })
      ..set(audit.newRef(_db), audit.toMap(uid: user.uid, userName: user.name));
    await batch.commit();
  }

  Future<void> updateCategory(ExpenseCategory c, {String? name, bool? active, required AppUser user}) async {
    final audit = AuditEntry(
      action: active == null ? AuditAction.update : (active ? AuditAction.activate : AuditAction.deactivate),
      entityType: Col.expenseCategories,
      entityId: c.id,
      summary: 'تعديل بند مصروفات: ${name ?? c.name}',
      before: {'name': c.name, 'active': c.active},
      after: {'name': name ?? c.name, 'active': active ?? c.active},
    );
    final batch = _db.batch()
      ..update(_categories.doc(c.id), {
        'name': ?name?.trim(),
        'active': ?active,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': user.uid,
      })
      ..set(audit.newRef(_db), audit.toMap(uid: user.uid, userName: user.name));
    await batch.commit();
  }

  Query<Map<String, dynamic>> query({
    String search = '',
    String? categoryId,
    DateRange? range,
    bool cancelledOnly = false,
  }) {
    final term = Keywords.term(search);
    if (term != null) {
      return _col.where('keywords', arrayContains: term).orderBy('date', descending: true);
    }
    Query<Map<String, dynamic>> q = _col;
    if (categoryId != null) q = q.where('categoryId', isEqualTo: categoryId);
    if (cancelledOnly) q = q.where('status', isEqualTo: 'cancelled');
    if (range != null) {
      q = q
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(range.from))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(range.to));
    }
    return q.orderBy('date', descending: true);
  }

  /// Uploads a receipt image/PDF for an expense. Returns its URL.
  Future<String> uploadAttachment(String expenseId, Uint8List bytes, String extension) async {
    try {
      final ref = _storage.ref('expenses/$expenseId/receipt.$extension');
      final type = extension == 'pdf' ? 'application/pdf' : 'image/$extension';
      await ref.putData(bytes, SettableMetadata(contentType: type));
      return await ref.getDownloadURL();
    } on FirebaseException catch (e) {
      if (e.code == 'unauthorized' || e.code == 'bucket-not-found' || e.code == 'unknown') {
        throw const AppException(
            'تعذر رفع المرفق. تأكد من تفعيل مساحة التخزين (Storage) في مشروع Firebase.');
      }
      rethrow;
    }
  }

  Future<PostingOutcome> create({
    required String postingId,
    required ExpenseCategory category,
    required Cashbox cashbox,
    required int amount,
    required DateTime date,
    required String description,
    required LedgerService ledger,
    String? attachmentUrl,
  }) {
    final ref = _col.doc(postingId);
    return ledger.post(PostingRequest(
      postingId: postingId,
      counter: Counter.expenses,
      build: (ctx) {
        final number = ctx.number!;
        return PostingDraft(
          posting: PostingFactory.expense(
            expenseId: ref.id,
            number: number,
            date: date,
            categoryName: category.name,
            cashboxId: cashbox.id,
            amount: amount,
            description: description,
          ),
          documents: [
            DocWrite.set(ref, {
              'number': number,
              'date': Timestamp.fromDate(date),
              'dayKey': Dates.dayKey(date),
              'categoryId': category.id,
              'categoryName': category.name,
              'amount': amount,
              'cashboxId': cashbox.id,
              'cashboxName': cashbox.name,
              'description': description.trim(),
              'attachmentUrl': attachmentUrl,
              'status': 'active',
              'financialTxId': postingId,
              'keywords': Keywords.build([number, category.name, description]),
              'createdAt': FieldValue.serverTimestamp(),
              'createdBy': ctx.actor.uid,
              'createdByName': ctx.actor.name,
            }),
          ],
          audit: AuditEntry(
            action: AuditAction.create,
            entityType: Col.expenses,
            entityId: ref.id,
            summary: 'مصروف $number: ${category.name}',
            after: {'amount': amount, 'cashbox': cashbox.name, 'description': description.trim()},
          ),
        );
      },
    ));
  }

  Future<void> cancel(Expense e, String reason, LedgerService ledger) {
    return ledger.cancel(
      sourceRef: _col.doc(e.id),
      reason: reason,
      audit: (_) => AuditEntry(
        action: AuditAction.cancel,
        entityType: Col.expenses,
        entityId: e.id,
        summary: 'إلغاء المصروف ${e.number} - $reason',
        before: {'amount': e.amount, 'status': 'active'},
        after: {'status': 'cancelled'},
      ),
    );
  }
}
