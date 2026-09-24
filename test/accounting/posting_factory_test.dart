import 'package:app_alfardos/core/accounting/accounting_exception.dart';
import 'package:app_alfardos/core/accounting/costing.dart';
import 'package:app_alfardos/core/accounting/invoice_calculator.dart';
import 'package:app_alfardos/core/accounting/posting.dart';
import 'package:app_alfardos/core/accounting/posting_factory.dart';
import 'package:app_alfardos/core/accounting/statement.dart';
import 'package:flutter_test/flutter_test.dart';

final date = DateTime(2026, 9, 1);

InvoiceTotals saleTotals({int discount = 0, int paid = 0}) =>
    InvoiceCalculator.calculate(
      lines: const [
        InvoiceLineInput(
            kind: LineKind.product, itemId: 'a', name: 'A', quantity: 2, unitPrice: 50000, unitCost: 30000),
        InvoiceLineInput(
            kind: LineKind.service, itemId: 's', name: 'S', quantity: 1, unitPrice: 50000, unitCost: 20000),
      ],
      discount: discount,
      paid: paid,
    );

/// Applies postings to in-memory balances, the same way the ledger service
/// applies them to Firestore documents.
class Books {
  final cash = <String, int>{};
  final customers = <String, int>{};
  final suppliers = <String, int>{};
  final stock = <String, StockState>{};
  var metrics = PostingMetrics.zero;

  void post(Posting p) {
    p.validate();
    for (final m in p.cash) {
      cash[m.cashboxId] = (cash[m.cashboxId] ?? 0) + m.amount;
    }
    for (final m in p.customers) {
      customers[m.partyId] = (customers[m.partyId] ?? 0) + m.amount;
    }
    for (final m in p.suppliers) {
      suppliers[m.partyId] = (suppliers[m.partyId] ?? 0) + m.amount;
    }
    for (final m in p.stock) {
      stock[m.productId] = const WeightedAverageCosting()
          .apply(stock[m.productId] ?? (quantity: 0, unitCost: 0), m);
    }
    metrics = metrics + p.metrics;
  }
}

void main() {
  group('Sales', () {
    test('cash sale: cashbox +total, no receivable, profit = price - cost', () {
      final p = PostingFactory.sale(
        saleId: 's1', number: 'INV-1', date: date,
        totals: saleTotals(paid: 150000), cashboxId: 'main',
      );
      expect(p.cashDelta, 150000);
      expect(p.receivableDelta, 0);
      expect(p.metrics.sales, 150000);
      expect(p.metrics.grossProfit, 150000 - 60000 - 20000);
      expect(p.inventoryDelta, -60000);
      expect(p.isBalanced, isTrue);
    });

    test('credit sale: receivable +total, cashbox untouched', () {
      final p = PostingFactory.sale(
        saleId: 's1', number: 'INV-1', date: date,
        totals: saleTotals(), customerId: 'c1', customerName: 'Ali',
      );
      expect(p.cash, isEmpty);
      expect(p.receivableDelta, 150000);
      expect(p.customers.single.increase, 150000);
      expect(p.metrics.cashIn, 0);
      expect(p.isBalanced, isTrue);
    });

    test('partial payment: statement shows debit total and credit paid', () {
      final p = PostingFactory.sale(
        saleId: 's1', number: 'INV-1', date: date,
        totals: saleTotals(paid: 30000), customerId: 'c1', cashboxId: 'main',
      );
      expect(p.customers.single.increase, 150000);
      expect(p.customers.single.decrease, 30000);
      expect(p.receivableDelta, 120000);
      expect(p.cashDelta, 30000);
    });

    test('credit sale to walk-in customer is rejected', () {
      expect(
        () => PostingFactory.sale(saleId: 's', number: '1', date: date, totals: saleTotals(paid: 1000), cashboxId: 'm'),
        throwsA(isA<AccountingException>()
            .having((e) => e.error, 'error', AccountingError.creditRequiresParty)),
      );
    });

    test('paid sale without cashbox is rejected', () {
      expect(
        () => PostingFactory.sale(saleId: 's', number: '1', date: date, totals: saleTotals(paid: 150000)),
        throwsA(isA<AccountingException>()
            .having((e) => e.error, 'error', AccountingError.cashboxRequired)),
      );
    });
  });

  group('Payments, expenses, transfers', () {
    test('customer payment: receivable -x, cashbox +x', () {
      final p = PostingFactory.customerPayment(
        paymentId: 'p', number: 'R-1', date: date, customerId: 'c1',
        customerName: 'Ali', cashboxId: 'main', amount: 300000,
      );
      expect(p.receivableDelta, -300000);
      expect(p.cashDelta, 300000);
      expect(p.customers.single.enforceNonNegative, isTrue);
      expect(p.metrics.netProfit, 0);
    });

    test('supplier payment: payable -x, cashbox -x', () {
      final p = PostingFactory.supplierPayment(
        paymentId: 'p', number: 'P-1', date: date, supplierId: 's1',
        supplierName: 'X', cashboxId: 'main', amount: 500000,
      );
      expect(p.payableDelta, -500000);
      expect(p.cashDelta, -500000);
      expect(p.metrics.netProfit, 0);
    });

    test('expense: expense +x, cashbox -x, profit -x', () {
      final p = PostingFactory.expense(
        expenseId: 'e', number: 'E-1', date: date, categoryName: 'Rent',
        cashboxId: 'main', amount: 200000,
      );
      expect(p.cashDelta, -200000);
      expect(p.metrics.expenses, 200000);
      expect(p.metrics.netProfit, -200000);
    });

    test('transfer moves money and is not revenue, expense or profit', () {
      final p = PostingFactory.transfer(
        transferId: 't', number: 'T-1', date: date, fromCashboxId: 'main',
        fromName: 'Main', toCashboxId: 'bank', toName: 'Bank', amount: 1000000,
      );
      expect(p.cash.map((m) => m.amount), [-1000000, 1000000]);
      expect(p.cashDelta, 0);
      expect(p.metrics.sales, 0);
      expect(p.metrics.expenses, 0);
      expect(p.metrics.netProfit, 0);
      expect(p.metrics.cashIn, 0);
      expect(p.metrics.cashOut, 0);
    });

    test('transfer to the same cashbox is rejected', () {
      expect(
        () => PostingFactory.transfer(
          transferId: 't', number: '1', date: date, fromCashboxId: 'a',
          fromName: 'A', toCashboxId: 'a', toName: 'A', amount: 10,
        ),
        throwsA(isA<AccountingException>()),
      );
    });

    test('zero and negative amounts are rejected', () {
      for (final amount in [0, -5]) {
        expect(
          () => PostingFactory.expense(expenseId: 'e', number: '1', date: date,
              categoryName: 'x', cashboxId: 'm', amount: amount),
          throwsA(isA<AccountingException>()),
        );
      }
    });
  });

  group('Opening balances', () {
    test('customer opening balance creates receivable backed by capital', () {
      final p = PostingFactory.customerOpening(
          customerId: 'c', customerName: 'Ali', date: date, amount: 50000);
      expect(p.receivableDelta, 50000);
      expect(p.capital, 50000);
      expect(p.metrics.sales, 0);
      expect(p.isBalanced, isTrue);
    });

    test('negative customer opening = customer credit', () {
      final p = PostingFactory.customerOpening(
          customerId: 'c', customerName: 'Ali', date: date, amount: -2000);
      expect(p.customers.single.decrease, 2000);
      expect(p.isBalanced, isTrue);
    });

    test('supplier and cashbox openings are balanced', () {
      expect(PostingFactory.supplierOpening(supplierId: 's', supplierName: 'X', date: date, amount: 7000).isBalanced, isTrue);
      expect(PostingFactory.cashboxOpening(cashboxId: 'm', cashboxName: 'M', date: date, amount: 9000).isBalanced, isTrue);
    });
  });

  group('Cancellation (reversal)', () {
    test('reversal negates every movement and metric', () {
      final sale = PostingFactory.sale(
        saleId: 's1', number: 'INV-1', date: date,
        totals: saleTotals(paid: 30000), customerId: 'c1', cashboxId: 'main',
      );
      final r = sale.reversed(reversalOfId: 'ft1', date: date, description: 'إلغاء');
      expect(r.type, PostingType.reversal);
      expect(r.originalType, PostingType.sale);
      expect(r.cashDelta, -sale.cashDelta);
      expect(r.receivableDelta, -sale.receivableDelta);
      expect(r.customers.single.increase, 30000);
      expect(r.customers.single.decrease, 150000);
      expect(r.inventoryDelta, -sale.inventoryDelta);
      expect(r.metrics.sales, -sale.metrics.sales);
      expect(r.metrics.salesCount, -1);
      expect(r.isBalanced, isTrue);
    });

    test('a reversal cannot itself be reversed', () {
      final r = PostingFactory.cashboxOpening(cashboxId: 'm', cashboxName: 'M', date: date, amount: 5)
          .reversed(reversalOfId: 'x', date: date, description: '');
      expect(() => r.reversed(reversalOfId: 'y', date: date, description: ''),
          throwsA(isA<AccountingException>()));
    });

    test('posting survives serialization round-trip', () {
      final sale = PostingFactory.sale(
        saleId: 's1', number: 'INV-1', date: date,
        totals: saleTotals(paid: 30000), customerId: 'c1', cashboxId: 'main',
      );
      final map = {
        'type': sale.type.name,
        'description': sale.description,
        'sourceCollection': sale.sourceCollection,
        'sourceId': sale.sourceId,
        'sourceNumber': sale.sourceNumber,
        ...sale.movementsToMap(),
        ...sale.metrics.toMap(),
        'capital': sale.capital,
      };
      final restored = Posting.fromMap(map, date);
      expect(restored.cashDelta, sale.cashDelta);
      expect(restored.receivableDelta, sale.receivableDelta);
      expect(restored.inventoryDelta, sale.inventoryDelta);
      expect(restored.metrics.netProfit, sale.metrics.netProfit);
      expect(restored.isBalanced, isTrue);
    });
  });

  group('End-to-end books', () {
    test('full business day keeps all balances consistent', () {
      final books = Books();
      books.post(PostingFactory.cashboxOpening(cashboxId: 'main', cashboxName: 'M', date: date, amount: 1000000));
      books.post(PostingFactory.supplierOpening(supplierId: 'sup', supplierName: 'S', date: date, amount: 200000));
      books.post(PostingFactory.customerOpening(customerId: 'c', customerName: 'C', date: date, amount: 50000));

      // Buy 10 units at 300.00 on credit, 1000.00 paid now.
      books.post(PostingFactory.purchase(
        purchaseId: 'p1', number: 'PO-1', date: date, supplierId: 'sup', cashboxId: 'main',
        totals: InvoiceCalculator.calculate(lines: const [
          InvoiceLineInput(kind: LineKind.product, itemId: 'a', name: 'A', quantity: 10, unitPrice: 30000),
        ], paid: 100000),
      ));
      expect(books.stock['a'], (quantity: 10.0, unitCost: 30000));
      expect(books.suppliers['sup'], 200000 + 200000);

      // Sell 2 units at 500.00 + service 500.00, cost of service 200.00, credit 1000.00 paid.
      books.post(PostingFactory.sale(
        saleId: 's1', number: 'INV-1', date: date, customerId: 'c', cashboxId: 'main',
        totals: saleTotals(paid: 100000),
      ));
      expect(books.stock['a']!.quantity, 8);

      books.post(PostingFactory.customerPayment(paymentId: 'r', number: 'R', date: date,
          customerId: 'c', customerName: 'C', cashboxId: 'main', amount: 30000));
      books.post(PostingFactory.supplierPayment(paymentId: 'sp', number: 'SP', date: date,
          supplierId: 'sup', supplierName: 'S', cashboxId: 'main', amount: 150000));
      books.post(PostingFactory.expense(expenseId: 'e', number: 'E', date: date,
          categoryName: 'Rent', cashboxId: 'main', amount: 40000));
      books.post(PostingFactory.transfer(transferId: 't', number: 'T', date: date,
          fromCashboxId: 'main', fromName: 'M', toCashboxId: 'bank', toName: 'B', amount: 100000));

      expect(books.cash['main'], 1000000 - 100000 + 100000 + 30000 - 150000 - 40000 - 100000);
      expect(books.cash['bank'], 100000);
      expect(books.customers['c'], 50000 + 150000 - 100000 - 30000);
      expect(books.suppliers['sup'], 400000 - 150000);

      // Revenue 1500 − COGS 600 − service cost 200 − expenses 400 = 300.
      expect(books.metrics.sales, 150000);
      expect(books.metrics.productCost, 60000);
      expect(books.metrics.serviceCost, 20000);
      expect(books.metrics.expenses, 40000);
      expect(books.metrics.netProfit, 30000);
      // Purchases are inventory, not an expense.
      expect(books.metrics.purchases, 300000);
    });

    test('cancelling a sale restores every balance and stock', () {
      final books = Books();
      books.post(PostingFactory.purchase(
        purchaseId: 'p1', number: 'PO-1', date: date, cashboxId: 'main',
        totals: InvoiceCalculator.calculate(lines: const [
          InvoiceLineInput(kind: LineKind.product, itemId: 'a', name: 'A', quantity: 10, unitPrice: 30000),
        ], paid: 300000),
      ));
      final before = (cash: books.cash['main'], stock: books.stock['a']);
      final sale = PostingFactory.sale(
        saleId: 's1', number: 'INV-1', date: date, customerId: 'c', cashboxId: 'main',
        totals: saleTotals(paid: 50000),
      );
      books.post(sale);
      books.post(sale.reversed(reversalOfId: 'x', date: date, description: ''));
      expect(books.cash['main'], before.cash);
      expect(books.customers['c'], 0);
      expect(books.stock['a'], before.stock);
      expect(books.metrics.sales, 0);
      expect(books.metrics.netProfit, 0);
      expect(books.metrics.salesCount, 0);
    });

    test('cancelling a purchase un-averages the cost', () {
      final books = Books();
      Posting buy(String id, double qty, int unitCost) => PostingFactory.purchase(
            purchaseId: id, number: id, date: date, supplierId: 'sup',
            totals: InvoiceCalculator.calculate(lines: [
              InvoiceLineInput(kind: LineKind.product, itemId: 'a', name: 'A', quantity: qty, unitPrice: unitCost),
            ]),
          );
      books.post(buy('1', 10, 10000));
      final second = buy('2', 10, 20000);
      books.post(second);
      expect(books.stock['a'], (quantity: 20.0, unitCost: 15000));
      books.post(second.reversed(reversalOfId: 'x', date: date, description: ''));
      expect(books.stock['a'], (quantity: 10.0, unitCost: 10000));
      expect(books.suppliers['sup'], 100000);
    });
  });

  group('Statement', () {
    test('running balance derives from entries', () {
      final s = Statement.build(opening: 1000, entries: [
        StatementEntry(id: '2', date: DateTime(2026, 1, 2), description: 'payment', increase: 0, decrease: 400),
        StatementEntry(id: '1', date: DateTime(2026, 1, 1), description: 'sale', increase: 900, decrease: 100),
      ]);
      expect(s.rows.map((r) => r.balance), [1800, 1400]);
      expect(s.closing, 1400);
      expect(s.opening + s.totalIncrease - s.totalDecrease, s.closing);
    });
  });
}
