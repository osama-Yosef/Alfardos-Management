import 'package:app_alfardos/core/accounting/accounting_exception.dart';
import 'package:app_alfardos/core/accounting/invoice_calculator.dart';
import 'package:app_alfardos/core/firebase/collections.dart';
import 'package:app_alfardos/core/ledger/ledger_service.dart';
import 'package:app_alfardos/features/auth/domain/app_user.dart';
import 'package:app_alfardos/features/cashboxes/data/cashbox_repository.dart';
import 'package:app_alfardos/features/cashboxes/domain/cashbox.dart';
import 'package:app_alfardos/features/catalog/data/catalog_repository.dart';
import 'package:app_alfardos/features/expenses/data/expense_repository.dart';
import 'package:app_alfardos/features/expenses/domain/expense.dart';
import 'package:app_alfardos/features/invoices/data/invoice_repository.dart';
import 'package:app_alfardos/features/invoices/domain/invoice.dart';
import 'package:app_alfardos/features/parties/data/party_repository.dart';
import 'package:app_alfardos/features/parties/domain/party.dart';
import 'package:app_alfardos/features/parties/domain/payment.dart';
import 'package:app_alfardos/core/utils/dates.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockStorage extends Mock implements FirebaseStorage {}

const admin = AppUser(
  uid: 'u1',
  email: 'a@x.com',
  name: 'Admin',
  roleId: 'admin',
  roleName: 'admin',
  permissions: {'admin'},
  active: true,
);

void main() {
  late FakeFirebaseFirestore db;
  late LedgerService ledger;
  late CashboxRepository boxes;
  late PartyRepository customers;
  late PartyRepository suppliers;
  late CatalogRepository catalog;
  late InvoiceRepository sales;
  late InvoiceRepository purchases;
  late ExpenseRepository expenses;
  var seq = 0;
  String newId() => 'p${seq++}';

  Future<Map<String, dynamic>> doc(String col, String id) async =>
      (await db.collection(col).doc(id).get()).data()!;
  Future<int> balance(String col, String id) async => (await doc(col, id))['balance'] as int;
  Future<Cashbox> box(String id) async => Cashbox.fromDoc(await db.collection(Col.cashboxes).doc(id).get());
  Future<Party> party(PartyKind k, String id) async =>
      Party.fromDoc(k, await db.collection(k.collection).doc(id).get());

  setUp(() async {
    db = FakeFirebaseFirestore();
    ledger = LedgerService(db, const LedgerActor(uid: 'u1', name: 'Admin'));
    boxes = CashboxRepository(db);
    customers = PartyRepository(db, PartyKind.customer);
    suppliers = PartyRepository(db, PartyKind.supplier);
    catalog = CatalogRepository(db);
    sales = InvoiceRepository(db, InvoiceKind.sale);
    purchases = InvoiceRepository(db, InvoiceKind.purchase);
    expenses = ExpenseRepository(db, _MockStorage());
    await db.collection(Col.settings).doc(DocIds.companySettings).set({'companyName': 'Test'});
  });

  Future<String> newBox(String name, int opening) => boxes.create(
      name: name, kind: CashboxKind.cash, notes: '', openingBalance: opening, user: admin, ledger: ledger);

  InvoiceSubmission sale({
    required List<InvoiceLineInput> lines,
    Party? customer,
    String? cashboxId,
    int paid = 0,
    int discount = 0,
    String? postingId,
  }) =>
      InvoiceSubmission(
        kind: InvoiceKind.sale,
        postingId: postingId ?? newId(),
        date: DateTime.now(),
        lines: lines,
        discount: discount,
        paid: paid,
        method: PaymentMethod.cash,
        notes: '',
        party: customer,
        cashboxId: cashboxId,
        cashboxName: 'Main',
      );

  test('full business flow keeps balances, stock, stats and ledger consistent', () async {
    final main = await newBox('Main', 1000000); // 10,000.00
    final bank = await newBox('Bank', 0);
    final cid = await customers.create(const PartyInput(name: 'علي'), user: admin, ledger: ledger, openingBalance: 50000);
    final sid = await suppliers.create(const PartyInput(name: 'مورد'), user: admin, ledger: ledger);
    final pid = await catalog.createProduct(const ProductInput(name: 'منتج', sellPrice: 50000),
        costPrice: 30000, openingQty: 0, user: admin, ledger: ledger);

    expect(await balance(Col.cashboxes, main), 1000000);
    expect(await balance(Col.customers, cid), 50000);

    // Purchase 10 units @ 300 on credit, 1000 paid.
    final pur = await purchases.create(
      InvoiceSubmission(
        kind: InvoiceKind.purchase,
        postingId: newId(),
        date: DateTime.now(),
        lines: [InvoiceLineInput(kind: LineKind.product, itemId: pid, name: 'منتج', quantity: 10, unitPrice: 30000)],
        discount: 0,
        paid: 100000,
        method: PaymentMethod.cash,
        notes: '',
        party: await party(PartyKind.supplier, sid),
        cashboxId: main,
        cashboxName: 'Main',
      ),
      ledger,
    );
    expect(pur.number, 'PUR-1001');
    expect(await balance(Col.suppliers, sid), 200000);
    expect((await doc(Col.products, pid))['stockQty'], 10.0);

    // Sale: 2 units @ 500 + service 500 (cost 200), 1000 paid, rest credit.
    final out = await sales.create(
      sale(
        lines: [
          InvoiceLineInput(kind: LineKind.product, itemId: pid, name: 'منتج', quantity: 2, unitPrice: 50000),
          const InvoiceLineInput(
              kind: LineKind.service, itemId: 'svc', name: 'تركيب', quantity: 1, unitPrice: 50000, unitCost: 20000),
        ],
        customer: await party(PartyKind.customer, cid),
        cashboxId: main,
        paid: 100000,
      ),
      ledger,
    );
    expect(out.number, 'INV-1001');
    final saleDoc = await doc(Col.sales, out.postingId);
    // Cost read from the product inside the transaction (weighted average 300).
    expect(saleDoc['productCost'], 60000);
    expect(saleDoc['grossProfit'], 150000 - 60000 - 20000);
    expect(await balance(Col.customers, cid), 50000 + 50000);
    expect((await doc(Col.products, pid))['stockQty'], 8.0);

    // Customer pays 300, supplier paid 1500, expense 400, transfer 1000.
    await customers.recordPayment(postingId: newId(), party: await party(PartyKind.customer, cid), cashboxId: main,
        cashboxName: 'Main', amount: 30000, date: DateTime.now(), method: PaymentMethod.cash, notes: '', ledger: ledger);
    await suppliers.recordPayment(postingId: newId(), party: await party(PartyKind.supplier, sid), cashboxId: main,
        cashboxName: 'Main', amount: 150000, date: DateTime.now(), method: PaymentMethod.cash, notes: '', ledger: ledger);
    await expenses.create(postingId: newId(), category: const ExpenseCategory(id: 'c', name: 'إيجار', active: true),
        cashbox: await box(main), amount: 40000, date: DateTime.now(), description: '', ledger: ledger);
    await boxes.transfer(postingId: newId(), from: await box(main), to: await box(bank), amount: 100000,
        date: DateTime.now(), notes: '', ledger: ledger);

    expect(await balance(Col.cashboxes, main), 1000000 - 100000 + 100000 + 30000 - 150000 - 40000 - 100000);
    expect(await balance(Col.cashboxes, bank), 100000);
    expect(await balance(Col.customers, cid), 70000);
    expect(await balance(Col.suppliers, sid), 50000);

    // Every balance equals the sum of its sub-ledger records.
    Future<int> subSum(String col, String field, String id) async {
      final s = await db.collection(col).where(field, isEqualTo: id).get();
      return s.docs.fold<int>(0, (a, d) => a + (d['amount'] as int));
    }
    expect(await subSum(Col.cashTransactions, 'cashboxId', main), await balance(Col.cashboxes, main));
    expect(await subSum(Col.cashTransactions, 'cashboxId', bank), await balance(Col.cashboxes, bank));
    expect(await subSum(Col.customerTransactions, 'customerId', cid), await balance(Col.customers, cid));
    expect(await subSum(Col.supplierTransactions, 'supplierId', sid), await balance(Col.suppliers, sid));

    // Daily statistics: revenue 1500, COGS 600, service cost 200, expenses 400.
    final stats = await doc(Col.dailyStats, Dates.dayKey(DateTime.now()));
    expect(stats['sales'], 150000);
    expect(stats['productCost'], 60000);
    expect(stats['serviceCost'], 20000);
    expect(stats['expenses'], 40000);
    expect(stats['purchases'], 300000);
    // Transfers and openings are not cash flow.
    expect(stats['cashIn'], 100000 + 30000);
    expect(stats['cashOut'], 100000 + 150000 + 40000);

    // Audit trail written for each operation.
    final audits = await db.collection(Col.auditLogs).get();
    expect(audits.docs.length, greaterThanOrEqualTo(9));
  });

  test('posting is idempotent: retrying the same id never double-posts', () async {
    final main = await newBox('Main', 0);
    final pid = await catalog.createProduct(const ProductInput(name: 'P', sellPrice: 1000),
        costPrice: 500, openingQty: 5, user: admin, ledger: ledger);
    final submission = sale(
      lines: [InvoiceLineInput(kind: LineKind.product, itemId: pid, name: 'P', quantity: 1, unitPrice: 1000)],
      cashboxId: main,
      paid: 1000,
      postingId: 'fixed-id',
    );
    await sales.create(submission, ledger);
    await expectLater(
      sales.create(submission, ledger),
      throwsA(isA<AccountingException>().having((e) => e.error, 'error', AccountingError.alreadyPosted)),
    );
    expect(await balance(Col.cashboxes, main), 1000);
    expect((await doc(Col.products, pid))['stockQty'], 4.0);
  });

  test('overdraft and over-payment are rejected atomically', () async {
    final main = await newBox('Main', 10000);
    await expectLater(
      expenses.create(postingId: newId(), category: const ExpenseCategory(id: 'c', name: 'x', active: true),
          cashbox: await box(main), amount: 10001, date: DateTime.now(), description: '', ledger: ledger),
      throwsA(isA<AccountingException>().having((e) => e.error, 'error', AccountingError.insufficientCash)),
    );
    expect(await balance(Col.cashboxes, main), 10000);
    expect((await db.collection(Col.expenses).get()).docs, isEmpty);
    expect((await db.collection(Col.financialTransactions).get()).docs.length, 1); // opening only

    final cid = await customers.create(const PartyInput(name: 'C'), user: admin, ledger: ledger, openingBalance: 500);
    await expectLater(
      customers.recordPayment(postingId: newId(), party: await party(PartyKind.customer, cid), cashboxId: main,
          cashboxName: 'Main', amount: 501, date: DateTime.now(), method: PaymentMethod.cash, notes: '', ledger: ledger),
      throwsA(isA<AccountingException>().having((e) => e.error, 'error', AccountingError.customerOverpayment)),
    );
    expect(await balance(Col.customers, cid), 500);
  });

  test('cancelling an invoice reverses everything and cannot be repeated', () async {
    final main = await newBox('Main', 0);
    final cid = await customers.create(const PartyInput(name: 'C'), user: admin, ledger: ledger);
    final pid = await catalog.createProduct(const ProductInput(name: 'P', sellPrice: 1000),
        costPrice: 600, openingQty: 10, user: admin, ledger: ledger);
    final out = await sales.create(
      sale(
        lines: [InvoiceLineInput(kind: LineKind.product, itemId: pid, name: 'P', quantity: 3, unitPrice: 1000)],
        customer: await party(PartyKind.customer, cid),
        cashboxId: main,
        paid: 1000,
      ),
      ledger,
    );
    expect(await balance(Col.customers, cid), 2000);
    final inv = Invoice.fromDoc(InvoiceKind.sale, await db.collection(Col.sales).doc(out.postingId).get());
    await sales.cancel(inv, 'خطأ في الإدخال', ledger);

    expect(await balance(Col.cashboxes, main), 0);
    expect(await balance(Col.customers, cid), 0);
    expect((await doc(Col.products, pid))['stockQty'], 10.0);
    expect((await doc(Col.products, pid))['costPrice'], 600);
    final cancelled = await doc(Col.sales, out.postingId);
    expect(cancelled['status'], 'cancelled');
    expect(cancelled['reversalTxId'], '${out.postingId}_rev');
    // The original remains; the reversal is a new record.
    expect((await db.collection(Col.financialTransactions).doc(out.postingId).get()).exists, isTrue);
    final stats = await doc(Col.dailyStats, Dates.dayKey(DateTime.now()));
    expect(stats['sales'], 0);
    expect(stats['salesCount'], 0);
    // Sale item analytics net to zero.
    final items = await db.collection(Col.saleItems).where('saleId', isEqualTo: out.postingId).get();
    expect(items.docs.fold<num>(0, (s, d) => s + (d['net'] as num)), 0);

    await expectLater(sales.cancel(inv, 'again', ledger), throwsA(isA<AccountingException>()));
    expect(await balance(Col.cashboxes, main), 0);
  });

  test('credit sale to walk-in customer is rejected before any write', () async {
    final pid = await catalog.createProduct(const ProductInput(name: 'P', sellPrice: 1000),
        costPrice: 600, openingQty: 1, user: admin, ledger: ledger);
    await expectLater(
      sales.create(sale(lines: [
        InvoiceLineInput(kind: LineKind.product, itemId: pid, name: 'P', quantity: 1, unitPrice: 1000),
      ]), ledger),
      throwsA(isA<AccountingException>().having((e) => e.error, 'error', AccountingError.creditRequiresParty)),
    );
    expect((await db.collection(Col.sales).get()).docs, isEmpty);
  });
}
