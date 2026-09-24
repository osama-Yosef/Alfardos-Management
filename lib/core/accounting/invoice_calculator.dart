import '../money/money.dart';
import 'accounting_exception.dart';

enum LineKind {
  product,
  service;

  static LineKind parse(String value) =>
      LineKind.values.firstWhere((e) => e.name == value, orElse: () => product);
}

/// One line of a sales or purchase invoice, as entered by the user.
///
/// [unitCost] is the *actual* cost per unit at the moment of the operation:
/// for products it is the current weighted-average cost read inside the
/// posting transaction; for services it is the configured service cost.
class InvoiceLineInput {
  const InvoiceLineInput({
    required this.kind,
    required this.itemId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    this.unitCost = 0,
  });

  final LineKind kind;
  final String itemId;
  final String name;
  final double quantity;

  /// Selling price (sales) or purchase cost (purchases), minor units.
  final int unitPrice;
  final int unitCost;

  int get grossTotal => Money.multiply(quantity, unitPrice);
  int get totalCost => Money.multiply(quantity, unitCost);

  InvoiceLineInput copyWith({double? quantity, int? unitPrice, int? unitCost}) =>
      InvoiceLineInput(
        kind: kind,
        itemId: itemId,
        name: name,
        quantity: quantity ?? this.quantity,
        unitPrice: unitPrice ?? this.unitPrice,
        unitCost: unitCost ?? this.unitCost,
      );
}

/// A calculated invoice line: gross total, its share of the invoice-level
/// discount, net revenue and cost.
class InvoiceLineResult {
  const InvoiceLineResult({
    required this.input,
    required this.grossTotal,
    required this.discountShare,
    required this.totalCost,
  });

  final InvoiceLineInput input;
  final int grossTotal;
  final int discountShare;
  final int totalCost;

  int get netTotal => grossTotal - discountShare;
  int get profit => netTotal - totalCost;
}

enum PaymentStatus {
  paid,
  partial,
  unpaid;

  static PaymentStatus of({required int total, required int paid}) {
    if (paid >= total) return PaymentStatus.paid;
    if (paid <= 0) return PaymentStatus.unpaid;
    return PaymentStatus.partial;
  }

  static PaymentStatus parse(String value) => PaymentStatus.values
      .firstWhere((e) => e.name == value, orElse: () => unpaid);
}

class InvoiceTotals {
  const InvoiceTotals({
    required this.lines,
    required this.subtotal,
    required this.discount,
    required this.paid,
  });

  final List<InvoiceLineResult> lines;
  final int subtotal;
  final int discount;
  final int paid;

  int get total => subtotal - discount;
  int get remaining => total - paid;

  int _sum(LineKind kind, int Function(InvoiceLineResult) pick) => lines
      .where((l) => l.input.kind == kind)
      .fold(0, (sum, l) => sum + pick(l));

  int get productRevenue => _sum(LineKind.product, (l) => l.netTotal);
  int get serviceRevenue => _sum(LineKind.service, (l) => l.netTotal);
  int get productCost => _sum(LineKind.product, (l) => l.totalCost);
  int get serviceCost => _sum(LineKind.service, (l) => l.totalCost);
  int get totalCost => productCost + serviceCost;
  int get grossProfit => total - totalCost;

  PaymentStatus get paymentStatus =>
      PaymentStatus.of(total: total, paid: paid);
}

/// Deterministic invoice math shared by sales and purchases.
///
/// The invoice-level discount is allocated to lines proportionally to their
/// gross totals using the largest-remainder method, so the per-line shares
/// always add up to the exact discount (no lost minor units). Allocation is
/// what lets product revenue and service revenue be reported separately.
abstract final class InvoiceCalculator {
  static InvoiceTotals calculate({
    required List<InvoiceLineInput> lines,
    int discount = 0,
    int paid = 0,
  }) {
    if (lines.isEmpty) {
      throw const AccountingException(AccountingError.emptyInvoice);
    }
    for (final line in lines) {
      if (!(line.quantity > 0)) {
        throw const AccountingException(AccountingError.invalidQuantity);
      }
      if (line.unitPrice < 0 || line.unitCost < 0) {
        throw const AccountingException(AccountingError.negativeAmount);
      }
    }
    final grosses = [for (final l in lines) l.grossTotal];
    final subtotal = grosses.fold(0, (a, b) => a + b);

    if (discount < 0 || paid < 0) {
      throw const AccountingException(AccountingError.negativeAmount);
    }
    if (discount > subtotal) {
      throw const AccountingException(AccountingError.discountExceedsTotal);
    }
    final total = subtotal - discount;
    if (paid > total) {
      throw const AccountingException(AccountingError.paidExceedsTotal);
    }

    final shares = allocate(discount, grosses);
    return InvoiceTotals(
      lines: [
        for (var i = 0; i < lines.length; i++)
          InvoiceLineResult(
            input: lines[i],
            grossTotal: grosses[i],
            discountShare: shares[i],
            totalCost: lines[i].totalCost,
          ),
      ],
      subtotal: subtotal,
      discount: discount,
      paid: paid,
    );
  }

  /// Splits [amount] across [weights] proportionally; the result always sums
  /// to [amount] exactly. Zero total weight puts everything on the first line.
  static List<int> allocate(int amount, List<int> weights) {
    if (weights.isEmpty) return const [];
    final totalWeight = weights.fold(0, (a, b) => a + b);
    if (amount == 0) return List.filled(weights.length, 0);
    if (totalWeight == 0) {
      return [amount, ...List.filled(weights.length - 1, 0)];
    }
    final shares = <int>[];
    final remainders = <({int index, double remainder})>[];
    var allocated = 0;
    for (var i = 0; i < weights.length; i++) {
      final exact = amount * weights[i] / totalWeight;
      final floor = exact.floor();
      shares.add(floor);
      allocated += floor;
      remainders.add((index: i, remainder: exact - floor));
    }
    remainders.sort((a, b) {
      final byRemainder = b.remainder.compareTo(a.remainder);
      return byRemainder != 0 ? byRemainder : a.index.compareTo(b.index);
    });
    var left = amount - allocated;
    for (var i = 0; left > 0; i = (i + 1) % remainders.length, left--) {
      shares[remainders[i].index] += 1;
    }
    return shares;
  }
}
