import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/accounting/accounting_exception.dart';
import '../../../core/accounting/invoice_calculator.dart';
import '../../../core/accounting/posting_factory.dart';
import '../../../core/accounting/recipe.dart';
import '../../../core/audit/audit_entry.dart';
import '../../../core/firebase/collections.dart';
import '../../../core/ledger/ledger_service.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/keywords.dart';
import '../domain/invoice.dart';

enum InvoiceFilter { all, unpaid, cancelled }

class InvoiceRepository {
  InvoiceRepository(this._db, this.kind);

  static const maxLines = 150;

  final FirebaseFirestore _db;
  final InvoiceKind kind;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection(kind.collection);

  Query<Map<String, dynamic>> query({
    String search = '',
    InvoiceFilter filter = InvoiceFilter.all,
    DateRange? range,
    String? partyId,
  }) {
    Query<Map<String, dynamic>> q = _col;
    final term = Keywords.term(search);
    if (term != null) {
      // Keyword search ignores other filters to keep index needs small.
      return q.where('keywords', arrayContains: term).orderBy('date', descending: true);
    }
    if (partyId != null) q = q.where('partyId', isEqualTo: partyId);
    switch (filter) {
      case InvoiceFilter.unpaid:
        q = q.where('status', isEqualTo: 'active').where('paymentStatus', whereIn: ['unpaid', 'partial']);
      case InvoiceFilter.cancelled:
        q = q.where('status', isEqualTo: 'cancelled');
      case InvoiceFilter.all:
        break;
    }
    if (range != null) {
      q = q
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(range.from))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(range.to));
    }
    return q.orderBy('date', descending: true);
  }

  Stream<Invoice> watch(String id) =>
      _col.doc(id).snapshots().map((d) => Invoice.fromDoc(kind, d));

  /// Posts an invoice: invoice document, item records, ledger entries,
  /// balances and stock — one atomic transaction.
  Future<PostingOutcome> create(InvoiceSubmission s, LedgerService ledger) async {
    if (s.lines.length > maxLines) {
      throw const AccountingException(AccountingError.tooManyLines);
    }
    final ref = _col.doc(s.postingId);
    final productIds = {
      for (final l in s.lines)
        if (l.kind == LineKind.product) l.itemId,
    };
    if (kind.isSale) {
      // Selling a manufactured product consumes its components, so they must
      // be read inside the transaction too. The recipe itself is re-read
      // there; this only tells the ledger which documents to read.
      final snaps = await Future.wait([
        for (final id in productIds) _db.collection(Col.products).doc(id).get(),
      ]);
      for (final snap in snaps) {
        productIds.addAll(RecipeComponent.listFrom(snap.data()?['components']).map((c) => c.productId));
      }
    }

    return ledger.post(PostingRequest(
      postingId: s.postingId,
      counter: kind.counter,
      productIds: productIds,
      build: (ctx) {
        final number = ctx.number!;
        // Sales use the product's *current* weighted-average cost, read
        // inside this transaction, as the actual cost of goods sold. A
        // manufactured product costs the sum of its components' costs.
        final recipes = <String, List<CostedComponent>>{};
        int saleCost(String productId) {
          final p = ctx.product(productId);
          if (!p.isManufactured) return p.costPrice;
          final components = recipes[productId] ??= [
            for (final c in p.components)
              CostedComponent(
                productId: c.productId,
                name: ctx.product(c.productId).name,
                quantity: c.quantity,
                unitCost: ctx.product(c.productId).costPrice,
              ),
          ];
          return Recipe.unitCost(components);
        }

        final lines = kind.isSale
            ? [
                for (final l in s.lines)
                  l.kind == LineKind.product ? l.copyWith(unitCost: saleCost(l.itemId)) : l,
              ]
            : s.lines;
        final totals = InvoiceCalculator.calculate(lines: lines, discount: s.discount, paid: s.paid);
        final posting = kind.isSale
            ? PostingFactory.sale(
                saleId: ref.id,
                number: number,
                date: s.date,
                totals: totals,
                customerId: s.party?.id,
                customerName: s.party?.name,
                cashboxId: totals.paid > 0 ? s.cashboxId : null,
                recipes: recipes,
              )
            : PostingFactory.purchase(
                purchaseId: ref.id,
                number: number,
                date: s.date,
                totals: totals,
                supplierId: s.party?.id,
                supplierName: s.party?.name,
                cashboxId: totals.paid > 0 ? s.cashboxId : null,
              );

        final partyName = s.party?.name ?? kind.walkInLabel;
        final invoiceLines = totals.lines.map(InvoiceLine.fromResult).toList();
        final documents = <DocWrite>[
          DocWrite.set(ref, {
            'number': number,
            'date': Timestamp.fromDate(s.date),
            'dayKey': Dates.dayKey(s.date),
            'partyId': s.party?.id,
            'partyName': partyName,
            'cashboxId': totals.paid > 0 ? s.cashboxId : null,
            'cashboxName': totals.paid > 0 ? s.cashboxName : null,
            'method': s.method.name,
            'lines': [for (final l in invoiceLines) l.toMap()],
            'lineCount': invoiceLines.length,
            'subtotal': totals.subtotal,
            'discount': totals.discount,
            'total': totals.total,
            'paid': totals.paid,
            'remaining': totals.remaining,
            'productCost': kind.isSale ? totals.productCost : 0,
            'serviceCost': kind.isSale ? totals.serviceCost : 0,
            'grossProfit': kind.isSale ? totals.grossProfit : 0,
            'paymentStatus': totals.paymentStatus.name,
            'status': 'active',
            'notes': s.notes.trim(),
            'financialTxId': s.postingId,
            'keywords': Keywords.build([number, partyName]),
            'createdAt': FieldValue.serverTimestamp(),
            'createdBy': ctx.actor.uid,
            'createdByName': ctx.actor.name,
          }),
          if (kind.isSale)
            for (var i = 0; i < invoiceLines.length; i++)
              DocWrite.set(
                _db.collection(Col.saleItems).doc('${ref.id}_$i'),
                _saleItem(ref.id, number, s.date, invoiceLines[i], sign: 1),
              ),
        ];

        return PostingDraft(
          posting: posting,
          documents: documents,
          audit: AuditEntry(
            action: AuditAction.create,
            entityType: kind.collection,
            entityId: ref.id,
            summary: '${kind.title} $number - $partyName',
            after: {'total': totals.total, 'paid': totals.paid, 'lines': invoiceLines.length},
          ),
        );
      },
    ));
  }

  /// Cancels an invoice by posting its exact reversal. The invoice stays in
  /// the books marked cancelled; sale item analytics get negative lines on
  /// the cancellation date so every report nets out correctly.
  Future<void> cancel(Invoice invoice, String reason, LedgerService ledger) {
    return ledger.cancel(
      sourceRef: _col.doc(invoice.id),
      reason: reason,
      audit: (_) => AuditEntry(
        action: AuditAction.cancel,
        entityType: kind.collection,
        entityId: invoice.id,
        summary: 'إلغاء ${kind.title} ${invoice.number} - $reason',
        before: {'status': 'active', 'total': invoice.total, 'paid': invoice.paid},
        after: {'status': 'cancelled'},
      ),
      extraWrites: kind.isSale
          ? (_, _, date) => [
                for (var i = 0; i < invoice.lines.length; i++)
                  DocWrite.set(
                    _db.collection(Col.saleItems).doc('${invoice.id}_${i}_r'),
                    _saleItem(invoice.id, invoice.number, date, invoice.lines[i], sign: -1),
                  ),
              ]
          : null,
    );
  }

  Map<String, dynamic> _saleItem(String saleId, String number, DateTime date, InvoiceLine l, {required int sign}) => {
        'saleId': saleId,
        'number': number,
        'date': Timestamp.fromDate(date),
        'dayKey': Dates.dayKey(date),
        'kind': l.kind.name,
        'itemId': l.itemId,
        'name': l.name,
        'qty': l.quantity * sign,
        'net': l.net * sign,
        'cost': l.cost * sign,
        'profit': l.profit * sign,
        'reversal': sign < 0,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
