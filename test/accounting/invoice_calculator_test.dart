import 'package:app_alfardos/core/accounting/accounting_exception.dart';
import 'package:app_alfardos/core/accounting/invoice_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

InvoiceLineInput product(double qty, int price, int cost, [String id = 'p']) =>
    InvoiceLineInput(
      kind: LineKind.product,
      itemId: id,
      name: id,
      quantity: qty,
      unitPrice: price,
      unitCost: cost,
    );

InvoiceLineInput service(double qty, int price, int cost, [String id = 's']) =>
    InvoiceLineInput(
      kind: LineKind.service,
      itemId: id,
      name: id,
      quantity: qty,
      unitPrice: price,
      unitCost: cost,
    );

void main() {
  group('InvoiceCalculator - spec example', () {
    // Product A: 2 × 500 (cost 300), Product B: 1 × 1000 (cost 700),
    // Installation service: 500 (cost 200). Amounts in minor units.
    final lines = [
      product(2, 50000, 30000, 'a'),
      product(1, 100000, 70000, 'b'),
      service(1, 50000, 20000, 'install'),
    ];

    test('subtotal, cost and gross profit without discount', () {
      final t = InvoiceCalculator.calculate(lines: lines);
      expect(t.subtotal, 250000);
      expect(t.total, 250000);
      expect(t.productCost, 130000);
      expect(t.serviceCost, 20000);
      expect(t.totalCost, 150000);
      expect(t.grossProfit, 100000);
      expect(t.productRevenue, 200000);
      expect(t.serviceRevenue, 50000);
    });

    test('discount reduces revenue and profit, not cost', () {
      final t = InvoiceCalculator.calculate(lines: lines, discount: 10000, paid: 100000);
      expect(t.total, 240000);
      expect(t.totalCost, 150000);
      expect(t.grossProfit, 90000);
      expect(t.remaining, 140000);
      expect(t.paymentStatus, PaymentStatus.partial);
      // Allocated discount shares add up exactly.
      expect(t.lines.fold(0, (s, l) => s + l.discountShare), 10000);
      expect(t.productRevenue + t.serviceRevenue, t.total);
    });
  });

  group('InvoiceCalculator - payments', () {
    test('fully paid invoice', () {
      final t = InvoiceCalculator.calculate(lines: [product(1, 1000, 500)], paid: 1000);
      expect(t.remaining, 0);
      expect(t.paymentStatus, PaymentStatus.paid);
    });

    test('credit invoice', () {
      final t = InvoiceCalculator.calculate(lines: [product(1, 1000, 500)]);
      expect(t.remaining, 1000);
      expect(t.paymentStatus, PaymentStatus.unpaid);
    });

    test('paid more than total is rejected', () {
      expect(
        () => InvoiceCalculator.calculate(lines: [product(1, 1000, 500)], paid: 1001),
        throwsA(isA<AccountingException>()
            .having((e) => e.error, 'error', AccountingError.paidExceedsTotal)),
      );
    });
  });

  group('InvoiceCalculator - validation', () {
    test('empty invoice', () {
      expect(() => InvoiceCalculator.calculate(lines: const []),
          throwsA(isA<AccountingException>()));
    });

    test('zero or negative quantity', () {
      expect(() => InvoiceCalculator.calculate(lines: [product(0, 100, 50)]),
          throwsA(isA<AccountingException>()
              .having((e) => e.error, 'error', AccountingError.invalidQuantity)));
      expect(() => InvoiceCalculator.calculate(lines: [product(-1, 100, 50)]),
          throwsA(isA<AccountingException>()));
    });

    test('negative price', () {
      expect(() => InvoiceCalculator.calculate(lines: [product(1, -100, 50)]),
          throwsA(isA<AccountingException>()
              .having((e) => e.error, 'error', AccountingError.negativeAmount)));
    });

    test('discount larger than subtotal', () {
      expect(
        () => InvoiceCalculator.calculate(lines: [product(1, 100, 50)], discount: 101),
        throwsA(isA<AccountingException>()
            .having((e) => e.error, 'error', AccountingError.discountExceedsTotal)),
      );
    });

    test('negative discount', () {
      expect(
        () => InvoiceCalculator.calculate(lines: [product(1, 100, 50)], discount: -1),
        throwsA(isA<AccountingException>()),
      );
    });
  });

  group('InvoiceCalculator - rounding', () {
    test('fractional quantities round to minor units', () {
      final t = InvoiceCalculator.calculate(lines: [product(1.5, 333, 111)]);
      expect(t.subtotal, 500); // 499.5 rounds half away from zero
      expect(t.productCost, 167); // 166.5
    });

    test('discount allocation never loses minor units', () {
      final shares = InvoiceCalculator.allocate(100, [1, 1, 1]);
      expect(shares.fold(0, (a, b) => a + b), 100);
      expect(shares, [34, 33, 33]);
    });

    test('allocation with zero weights', () {
      expect(InvoiceCalculator.allocate(50, [0, 0]), [50, 0]);
    });

    test('100% discount', () {
      final t = InvoiceCalculator.calculate(
          lines: [product(1, 700, 300), service(1, 300, 100)], discount: 1000);
      expect(t.total, 0);
      expect(t.grossProfit, -400);
      expect(t.paymentStatus, PaymentStatus.paid);
    });
  });
}
