import 'package:cloud_firestore/cloud_firestore.dart';

import '../accounting/accounting_exception.dart';
import '../accounting/costing.dart';
import '../accounting/posting.dart';
import '../accounting/recipe.dart';
import '../audit/audit_entry.dart';
import '../firebase/collections.dart';
import '../settings/company_settings.dart';
import '../utils/dates.dart';

typedef Json = Map<String, dynamic>;
typedef DocRef = DocumentReference<Json>;
typedef DocSnap = DocumentSnapshot<Json>;

/// The user performing an operation (stamped on every record).
class LedgerActor {
  const LedgerActor({required this.uid, required this.name});
  final String uid;
  final String name;
}

/// Product state read inside the posting transaction.
class ProductSnapshot {
  const ProductSnapshot({
    required this.id,
    required this.name,
    required this.stockQty,
    required this.costPrice,
    required this.active,
    this.components = const [],
  });

  final String id;
  final String name;
  final double stockQty;
  final int costPrice;
  final bool active;

  /// Non-empty for a manufactured product (see [Recipe]).
  final List<RecipeComponent> components;

  bool get isManufactured => components.isNotEmpty;
}

/// Everything a posting builder may need, read atomically inside the
/// transaction so costs, balances and numbers are always current.
class LedgerReadContext {
  LedgerReadContext({
    required this.settings,
    required this.products,
    required this.extra,
    required this.actor,
    this.number,
  });

  final CompanySettings settings;
  final Map<String, ProductSnapshot> products;
  final Map<String, DocSnap> extra;
  final LedgerActor actor;

  /// Formatted document number (e.g. INV-1001) when a counter was requested.
  final String? number;

  DocSnap doc(DocRef ref) => extra[ref.path]!;

  ProductSnapshot product(String id) {
    final p = products[id];
    if (p == null) throw const AccountingException(AccountingError.notFound, 'منتج');
    return p;
  }
}

/// A plain document write that is part of the same atomic operation
/// (the invoice document itself, its lines, a status change, ...).
class DocWrite {
  const DocWrite.set(this.ref, this.data) : update = false;
  const DocWrite.update(this.ref, this.data) : update = true;

  final DocRef ref;
  final Json data;
  final bool update;
}

class PostingDraft {
  const PostingDraft({
    required this.posting,
    required this.audit,
    this.documents = const [],
    this.newAccounts = const {},
  });

  final Posting posting;
  final AuditEntry audit;
  final List<DocWrite> documents;

  /// Accounts (customer/supplier/cashbox) created by this same operation,
  /// keyed by document path, e.g. a new customer with an opening balance.
  final Map<String, Json> newAccounts;
}

class PostingRequest {
  const PostingRequest({
    required this.postingId,
    required this.build,
    this.counter,
    this.productIds = const {},
    this.extraReads = const [],
  });

  /// Id of the `financial_transactions` document. Generated once when a form
  /// opens and reused on retry, which makes every posting idempotent.
  final String postingId;
  final Counter? counter;
  final Set<String> productIds;
  final List<DocRef> extraReads;
  final PostingDraft Function(LedgerReadContext ctx) build;
}

class PostingOutcome {
  const PostingOutcome({required this.postingId, this.number});
  final String postingId;
  final String? number;
}

/// The central accounting engine.
///
/// Every financial operation in the app goes through [post]. In one Firestore
/// transaction it:
///  1. rejects duplicates (idempotency on [PostingRequest.postingId]);
///  2. reads settings, counters, products and every affected account;
///  3. builds and validates a balanced [Posting];
///  4. enforces business rules (overdraft, over-payment, stock, inactive);
///  5. writes the immutable financial transaction, one sub-ledger record per
///     account, the new balances (each linked to its sub-ledger record via
///     `lastTxId`, which security rules verify), stock and average cost,
///     daily statistics, the business document, notifications and the
///     audit log.
///
/// Either everything is written or nothing is. Transactions require a
/// server round-trip, so financial operations never produce "pending" local
/// balances while offline.
class LedgerService {
  LedgerService(this._db, this._actor, {this._costing = const WeightedAverageCosting()});

  final FirebaseFirestore _db;
  final LedgerActor _actor;
  final CostingPolicy _costing;

  CollectionReference<Json> _col(String name) => _db.collection(name);

  Future<PostingOutcome> post(PostingRequest request) {
    return _db.runTransaction<PostingOutcome>(
      (tx) => _run(tx, request),
      timeout: const Duration(seconds: 30),
      maxAttempts: 5,
    );
  }

  /// Cancels a posted operation by writing its exact reversal.
  ///
  /// [sourceRef] is the business document (invoice, payment, ...) whose
  /// `financialTxId` is reversed; it is marked `cancelled` atomically.
  Future<PostingOutcome> cancel({
    required DocRef sourceRef,
    required String reason,
    required AuditEntry Function(Json source) audit,
    List<DocWrite> Function(Json source, String reversalId, DateTime date)?
        extraWrites,
  }) async {
    final source = await sourceRef.get();
    final data = source.data();
    if (data == null) throw const AccountingException(AccountingError.notFound);
    final originalId = data['financialTxId'] as String;
    final originalRef = _col(Col.financialTransactions).doc(originalId);
    final reversalId = '${originalId}_rev';

    return post(PostingRequest(
      postingId: reversalId,
      extraReads: [sourceRef, originalRef],
      build: (ctx) {
        final src = ctx.doc(sourceRef).data();
        final orig = ctx.doc(originalRef).data();
        if (src == null || orig == null) {
          throw const AccountingException(AccountingError.notFound);
        }
        if (src['status'] == 'cancelled') {
          throw const AccountingException(AccountingError.alreadyCancelled);
        }
        final now = DateTime.now();
        final original = Posting.fromMap(orig, (orig['date'] as Timestamp).toDate());
        final reversal = original.reversed(
          reversalOfId: originalId,
          date: now,
          description: 'إلغاء ${original.description}'
              '${reason.trim().isEmpty ? '' : ' - ${reason.trim()}'}',
        );
        return PostingDraft(
          posting: reversal,
          audit: audit(src),
          documents: [
            DocWrite.update(sourceRef, {
              'status': 'cancelled',
              'cancelReason': reason.trim(),
              'cancelledAt': FieldValue.serverTimestamp(),
              'cancelledBy': _actor.uid,
              'cancelledByName': _actor.name,
              'reversalTxId': reversalId,
              'updatedAt': FieldValue.serverTimestamp(),
              'updatedBy': _actor.uid,
            }),
            ...?extraWrites?.call(src, reversalId, now),
          ],
        );
      },
    ));
  }

  Future<PostingOutcome> _run(Transaction tx, PostingRequest request) async {
    // ---- 1. Reads (Firestore requires all reads before any write) --------
    final ftRef = _col(Col.financialTransactions).doc(request.postingId);
    if ((await tx.get(ftRef)).exists) {
      throw const AccountingException(AccountingError.alreadyPosted);
    }

    final settingsSnap =
        await tx.get(_col(Col.settings).doc(DocIds.companySettings));
    final settings = CompanySettings.fromMap(settingsSnap.data());

    String? number;
    int? nextValue;
    DocRef? counterRef;
    if (request.counter != null) {
      counterRef = _col(Col.counters).doc(request.counter!.id);
      final c = await tx.get(counterRef);
      nextValue = ((c.data()?['value'] as num?)?.toInt() ?? 1000) + 1;
      number = '${settings.prefixFor(request.counter!)}$nextValue';
    }

    final productSnaps = <String, DocSnap>{};
    for (final id in request.productIds) {
      productSnaps[id] = await tx.get(_col(Col.products).doc(id));
    }

    final extra = <String, DocSnap>{};
    for (final ref in request.extraReads) {
      extra[ref.path] = await tx.get(ref);
    }

    final ctx = LedgerReadContext(
      settings: settings,
      products: {
        for (final e in productSnaps.entries)
          if (e.value.exists) e.key: _productOf(e.value),
      },
      extra: extra,
      actor: _actor,
      number: number,
    );

    final draft = request.build(ctx);
    final posting = draft.posting..validate();
    final isReversal = posting.type == PostingType.reversal;

    // Accounts touched by the posting.
    final cashSnaps = <String, DocSnap>{};
    for (final m in posting.cash) {
      cashSnaps[m.cashboxId] = await tx.get(_col(Col.cashboxes).doc(m.cashboxId));
    }
    final customerSnaps = <String, DocSnap>{};
    for (final m in posting.customers) {
      customerSnaps[m.partyId] = await tx.get(_col(Col.customers).doc(m.partyId));
    }
    final supplierSnaps = <String, DocSnap>{};
    for (final m in posting.suppliers) {
      supplierSnaps[m.partyId] = await tx.get(_col(Col.suppliers).doc(m.partyId));
    }
    for (final m in posting.stock) {
      if (!productSnaps.containsKey(m.productId)) {
        productSnaps[m.productId] = await tx.get(_col(Col.products).doc(m.productId));
      }
    }
    final statsRef = _col(Col.dailyStats).doc(Dates.dayKey(posting.date));
    final statsExists = (await tx.get(statsRef)).exists;

    // ---- 2. Validation ----------------------------------------------------
    Json accountData(DocSnap snap) {
      final data = snap.data() ?? draft.newAccounts[snap.reference.path];
      if (data == null) {
        throw const AccountingException(AccountingError.notFound);
      }
      if (!isReversal && data['active'] == false) {
        throw AccountingException(
            AccountingError.inactiveAccount, data['name'] as String?);
      }
      return data;
    }

    int balanceOf(Json data) => (data['balance'] as num?)?.toInt() ?? 0;

    final newCash = <String, int>{};
    for (final m in posting.cash) {
      final data = accountData(cashSnaps[m.cashboxId]!);
      final after = balanceOf(data) + m.amount;
      if (m.amount < 0 && after < 0 && !settings.allowNegativeCash) {
        throw AccountingException(
            AccountingError.insufficientCash, data['name'] as String?);
      }
      newCash[m.cashboxId] = after;
    }

    Map<String, int> partyBalances(
      List<PartyMovement> moves,
      Map<String, DocSnap> snaps,
      bool allowOverpayment,
      AccountingError overpaymentError,
    ) {
      final result = <String, int>{};
      for (final m in moves) {
        final data = accountData(snaps[m.partyId]!);
        final after = balanceOf(data) + m.amount;
        if (m.enforceNonNegative && after < 0 && !allowOverpayment) {
          throw AccountingException(overpaymentError, data['name'] as String?);
        }
        result[m.partyId] = after;
      }
      return result;
    }

    final newCustomer = partyBalances(posting.customers, customerSnaps,
        settings.allowCustomerOverpayment, AccountingError.customerOverpayment);
    final newSupplier = partyBalances(posting.suppliers, supplierSnaps,
        settings.allowSupplierOverpayment, AccountingError.supplierOverpayment);

    final newStock = <String, StockState>{};
    for (final m in posting.stock) {
      final snap = productSnaps[m.productId]!;
      final isNew = !snap.exists && draft.newAccounts.containsKey(snap.reference.path);
      if (!snap.exists && !isNew) {
        throw AccountingException(AccountingError.notFound, m.name);
      }
      final p = isNew
          ? ProductSnapshot(id: m.productId, name: m.name, stockQty: 0, costPrice: 0, active: true)
          : _productOf(snap);
      if (p.isManufactured) {
        throw AccountingException(AccountingError.manufacturedNotStockable, p.name);
      }
      final current =
          newStock[m.productId] ?? (quantity: p.stockQty, unitCost: p.costPrice);
      final next = _costing.apply(current, m);
      if (m.quantity < 0 && next.quantity < 0 && !settings.allowNegativeStock) {
        throw AccountingException(AccountingError.insufficientStock, p.name);
      }
      newStock[m.productId] = next;
    }

    // ---- 3. Writes --------------------------------------------------------
    final now = FieldValue.serverTimestamp();
    final dayKey = Dates.dayKey(posting.date);
    final dateTs = Timestamp.fromDate(posting.date);
    final stamp = {
      'createdAt': now,
      'createdBy': _actor.uid,
      'createdByName': _actor.name,
    };
    final common = {
      'date': dateTs,
      'dayKey': dayKey,
      'type': posting.type.name,
      'originalType': posting.originalType?.name,
      'description': posting.description,
      'financialTxId': request.postingId,
      'sourceCollection': posting.sourceCollection,
      'sourceId': posting.sourceId,
      'sourceNumber': posting.sourceNumber ?? number,
      ...stamp,
    };

    final metrics = posting.type.countsAsCashFlow ||
            (isReversal && posting.originalType!.countsAsCashFlow)
        ? posting.metrics
        : _withoutCashFlow(posting.metrics);

    tx.set(ftRef, {
      'type': posting.type.name,
      'originalType': posting.originalType?.name,
      'reversalOf': posting.reversalOf,
      'date': dateTs,
      'dayKey': dayKey,
      'description': posting.description,
      'sourceCollection': posting.sourceCollection,
      'sourceId': posting.sourceId,
      'sourceNumber': posting.sourceNumber ?? number,
      'partyName': posting.partyName,
      'capital': posting.capital,
      ...posting.movementsToMap(),
      ...metrics.toMap(),
      'netProfit': metrics.netProfit,
      'amount': _headlineAmount(posting),
      ...stamp,
    });

    for (final m in posting.cash) {
      final id = '${request.postingId}_${m.cashboxId}';
      final ref = _col(Col.cashTransactions).doc(id);
      tx.set(ref, {
        ...common,
        'cashboxId': m.cashboxId,
        'amount': m.amount,
        'balanceAfter': newCash[m.cashboxId],
      });
      final snap = cashSnaps[m.cashboxId]!;
      _writeAccount(tx, snap, draft, {
        'balance': newCash[m.cashboxId],
        'lastTxId': id,
        'totalIn': FieldValue.increment(m.amount > 0 ? m.amount : 0),
        'totalOut': FieldValue.increment(m.amount < 0 ? -m.amount : 0),
        'lastTxAt': now,
      });
    }

    void writeParty(
      String txCol,
      String idField,
      PartyMovement m,
      DocSnap snap,
      int balanceAfter,
      PostingType invoiceType,
    ) {
      final id = '${request.postingId}_${m.partyId}';
      tx.set(_col(txCol).doc(id), {
        ...common,
        idField: m.partyId,
        'increase': m.increase,
        'decrease': m.decrease,
        'amount': m.amount,
        'balanceAfter': balanceAfter,
      });
      final invoiceDelta = posting.type == invoiceType
          ? 1
          : (isReversal && posting.originalType == invoiceType ? -1 : 0);
      _writeAccount(tx, snap, draft, {
        'balance': balanceAfter,
        'lastTxId': id,
        'totalIncrease': FieldValue.increment(m.increase),
        'totalDecrease': FieldValue.increment(m.decrease),
        'invoiceCount': FieldValue.increment(invoiceDelta),
        'lastTxAt': now,
      });
    }

    for (final m in posting.customers) {
      writeParty(Col.customerTransactions, 'customerId', m,
          customerSnaps[m.partyId]!, newCustomer[m.partyId]!, PostingType.sale);
    }
    for (final m in posting.suppliers) {
      writeParty(Col.supplierTransactions, 'supplierId', m,
          supplierSnaps[m.partyId]!, newSupplier[m.partyId]!, PostingType.purchase);
    }

    for (final e in newStock.entries) {
      final ref = _col(Col.products).doc(e.key);
      final created = draft.newAccounts[ref.path];
      final stock = {
        'stockQty': e.value.quantity,
        'costPrice': e.value.unitCost,
        'updatedAt': now,
      };
      if (created != null && !productSnaps[e.key]!.exists) {
        tx.set(ref, {...created, ...stock});
      } else {
        tx.update(ref, stock);
      }
    }

    // Lets security rules require a brand-new financial transaction for
    // every change to the statistics.
    final statsMeta = {'lastTxId': request.postingId, 'updatedAt': now};
    if (statsExists) {
      tx.update(statsRef, {
        for (final e in metrics.toMap().entries)
          if (e.value != 0) e.key: FieldValue.increment(e.value),
        'txCount': FieldValue.increment(1),
        ...statsMeta,
      });
    } else {
      tx.set(statsRef, {
        'date': Timestamp.fromDate(Dates.startOfDay(posting.date)),
        'dayKey': dayKey,
        ...metrics.toMap(),
        'txCount': 1,
        ...statsMeta,
      });
    }

    if (counterRef != null) {
      tx.set(counterRef, {'value': nextValue, 'updatedAt': now});
    }

    for (final w in draft.documents) {
      if (w.update) {
        tx.update(w.ref, w.data);
      } else {
        tx.set(w.ref, w.data);
      }
    }

    _writeNotifications(tx, posting, settings, cashSnaps, newCash);

    final audit = draft.audit;
    tx.set(audit.newRef(_db), {
      ...audit.toMap(uid: _actor.uid, userName: _actor.name),
      'financialTxId': request.postingId,
      'number': number ?? posting.sourceNumber,
    });

    return PostingOutcome(postingId: request.postingId, number: number);
  }

  void _writeAccount(Transaction tx, DocSnap snap, PostingDraft draft, Json updates) {
    final created = draft.newAccounts[snap.reference.path];
    if (!snap.exists && created != null) {
      // Account created by this same operation: set() the full document.
      // FieldValue.increment on a missing field starts from zero, so the
      // statistics counters are correct without special handling.
      tx.set(snap.reference, {...created, ...updates});
    } else {
      tx.update(snap.reference, {...updates, 'updatedAt': FieldValue.serverTimestamp()});
    }
  }

  void _writeNotifications(
    Transaction tx,
    Posting posting,
    CompanySettings settings,
    Map<String, DocSnap> cashSnaps,
    Map<String, int> newCash,
  ) {
    void notify(String kind, String title, String body, {String? route}) {
      tx.set(_col(Col.notifications).doc(), {
        'kind': kind,
        'title': title,
        'body': body,
        'route': route,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': _actor.uid,
      });
    }

    if (settings.lowCashThreshold > 0) {
      for (final m in posting.cash) {
        final before = (cashSnaps[m.cashboxId]!.data()?['balance'] as num?)?.toInt() ?? 0;
        final after = newCash[m.cashboxId]!;
        if (after < settings.lowCashThreshold && before >= settings.lowCashThreshold) {
          final name = cashSnaps[m.cashboxId]!.data()?['name'] ?? '';
          notify('low_cash', 'رصيد منخفض في الخزنة',
              'انخفض رصيد "$name" عن الحد المحدد في الإعدادات.',
              route: '/cashboxes/${m.cashboxId}');
        }
      }
    }
    if (posting.type == PostingType.expense &&
        settings.largeExpenseThreshold > 0 &&
        posting.metrics.expenses >= settings.largeExpenseThreshold) {
      notify('large_expense', 'مصروف كبير', '${posting.description} بواسطة ${_actor.name}',
          route: '/expenses');
    }
  }

  static ProductSnapshot _productOf(DocSnap snap) {
    final m = snap.data() ?? const {};
    return ProductSnapshot(
      id: snap.id,
      name: m['name'] as String? ?? '',
      stockQty: (m['stockQty'] as num?)?.toDouble() ?? 0,
      costPrice: (m['costPrice'] as num?)?.toInt() ?? 0,
      active: m['active'] as bool? ?? true,
      components: RecipeComponent.listFrom(m['components']),
    );
  }

  static PostingMetrics _withoutCashFlow(PostingMetrics m) => PostingMetrics(
        sales: m.sales,
        serviceRevenue: m.serviceRevenue,
        productCost: m.productCost,
        serviceCost: m.serviceCost,
        expenses: m.expenses,
        purchases: m.purchases,
        customerReceipts: m.customerReceipts,
        supplierPayments: m.supplierPayments,
        salesCount: m.salesCount,
      );

  /// The single most meaningful amount of a posting, for activity feeds.
  static int _headlineAmount(Posting p) {
    final m = p.metrics;
    final type = p.effectiveType;
    final sign = p.type == PostingType.reversal ? -1 : 1;
    final value = switch (type) {
      PostingType.sale => m.sales.abs(),
      PostingType.purchase => m.purchases.abs(),
      PostingType.customerPayment => m.customerReceipts.abs(),
      PostingType.supplierPayment => m.supplierPayments.abs(),
      PostingType.expense => m.expenses.abs(),
      PostingType.transfer =>
        p.cash.isEmpty ? 0 : p.cash.map((c) => c.amount.abs()).reduce((a, b) => a > b ? a : b),
      _ => p.capital.abs(),
    };
    return sign * value;
  }
}
