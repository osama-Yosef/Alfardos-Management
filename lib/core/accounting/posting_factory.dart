import 'accounting_exception.dart';
import 'invoice_calculator.dart';
import 'posting.dart';
import 'recipe.dart';

/// Builds the [Posting] for every kind of financial operation.
///
/// This is the single place that decides *which accounts move and by how
/// much*. It is pure Dart (no Firebase) so every rule is unit-tested.
abstract final class PostingFactory {
  /// Sales invoice.
  ///
  /// * Paid part → cashbox in.
  /// * Registered customer → statement line: increase = total, decrease = paid
  ///   (net effect: receivable grows by the remaining amount).
  /// * Products leave stock at their actual cost (COGS); services recognise
  ///   their configured cost.
  /// * A manufactured product (a key of [recipes]) has no stock of its own:
  ///   its components leave stock instead, and the line cost is split across
  ///   them in proportion to their cost, so inventory moves by exactly the
  ///   cost of goods sold.
  static Posting sale({
    required String saleId,
    required String number,
    required DateTime date,
    required InvoiceTotals totals,
    String? customerId,
    String? customerName,
    String? cashboxId,
    Map<String, List<CostedComponent>> recipes = const {},
  }) {
    if (totals.paid > 0 && cashboxId == null) {
      throw const AccountingException(AccountingError.cashboxRequired);
    }
    if (totals.remaining > 0 && customerId == null) {
      throw const AccountingException(AccountingError.creditRequiresParty);
    }
    final posting = Posting(
      type: PostingType.sale,
      date: date,
      description: 'فاتورة بيع رقم $number',
      sourceCollection: 'sales',
      sourceId: saleId,
      sourceNumber: number,
      partyName: customerName,
      cash: [
        if (totals.paid > 0) CashMovement(cashboxId!, totals.paid),
      ],
      customers: [
        if (customerId != null)
          PartyMovement(customerId, increase: totals.total, decrease: totals.paid),
      ],
      stock: [
        for (final line in totals.lines)
          if (line.input.kind == LineKind.product)
            ...recipes.containsKey(line.input.itemId)
                ? _componentMovements(line, recipes[line.input.itemId]!)
                : [
                    StockMovement(
                      productId: line.input.itemId,
                      name: line.input.name,
                      quantity: -line.input.quantity,
                      value: -line.totalCost,
                    ),
                  ],
      ],
      metrics: PostingMetrics(
        sales: totals.total,
        serviceRevenue: totals.serviceRevenue,
        productCost: totals.productCost,
        serviceCost: totals.serviceCost,
        cashIn: totals.paid,
        salesCount: 1,
      ),
    );
    posting.validate();
    return posting;
  }

  /// Purchase invoice. Goods enter stock at their net (after-discount) cost;
  /// purchases are an inventory asset, not an expense, so profit is unchanged.
  static Posting purchase({
    required String purchaseId,
    required String number,
    required DateTime date,
    required InvoiceTotals totals,
    String? supplierId,
    String? supplierName,
    String? cashboxId,
  }) {
    if (totals.paid > 0 && cashboxId == null) {
      throw const AccountingException(AccountingError.cashboxRequired);
    }
    if (totals.remaining > 0 && supplierId == null) {
      throw const AccountingException(AccountingError.creditRequiresParty);
    }
    final posting = Posting(
      type: PostingType.purchase,
      date: date,
      description: 'فاتورة شراء رقم $number',
      sourceCollection: 'purchases',
      sourceId: purchaseId,
      sourceNumber: number,
      partyName: supplierName,
      cash: [
        if (totals.paid > 0) CashMovement(cashboxId!, -totals.paid),
      ],
      suppliers: [
        if (supplierId != null)
          PartyMovement(supplierId, increase: totals.total, decrease: totals.paid),
      ],
      stock: [
        for (final line in totals.lines)
          StockMovement(
            productId: line.input.itemId,
            name: line.input.name,
            quantity: line.input.quantity,
            value: line.netTotal,
          ),
      ],
      metrics: PostingMetrics(purchases: totals.total, cashOut: totals.paid),
    );
    posting.validate();
    return posting;
  }

  static Posting customerPayment({
    required String paymentId,
    required String number,
    required DateTime date,
    required String customerId,
    required String customerName,
    required String cashboxId,
    required int amount,
    String? notes,
  }) {
    _requirePositive(amount);
    return _validated(Posting(
      type: PostingType.customerPayment,
      date: date,
      description: _withNotes('تحصيل من العميل $customerName', notes),
      sourceCollection: 'customer_payments',
      sourceId: paymentId,
      sourceNumber: number,
      partyName: customerName,
      cash: [CashMovement(cashboxId, amount)],
      customers: [
        PartyMovement(customerId, decrease: amount, enforceNonNegative: true),
      ],
      metrics: PostingMetrics(cashIn: amount, customerReceipts: amount),
    ));
  }

  static Posting supplierPayment({
    required String paymentId,
    required String number,
    required DateTime date,
    required String supplierId,
    required String supplierName,
    required String cashboxId,
    required int amount,
    String? notes,
  }) {
    _requirePositive(amount);
    return _validated(Posting(
      type: PostingType.supplierPayment,
      date: date,
      description: _withNotes('دفع للمورد $supplierName', notes),
      sourceCollection: 'supplier_payments',
      sourceId: paymentId,
      sourceNumber: number,
      partyName: supplierName,
      cash: [CashMovement(cashboxId, -amount)],
      suppliers: [
        PartyMovement(supplierId, decrease: amount, enforceNonNegative: true),
      ],
      metrics: PostingMetrics(cashOut: amount, supplierPayments: amount),
    ));
  }

  static Posting expense({
    required String expenseId,
    required String number,
    required DateTime date,
    required String categoryName,
    required String cashboxId,
    required int amount,
    String? description,
  }) {
    _requirePositive(amount);
    return _validated(Posting(
      type: PostingType.expense,
      date: date,
      description: _withNotes('مصروف: $categoryName', description),
      sourceCollection: 'expenses',
      sourceId: expenseId,
      sourceNumber: number,
      cash: [CashMovement(cashboxId, -amount)],
      metrics: PostingMetrics(expenses: amount, cashOut: amount),
    ));
  }

  /// Moving money between cashboxes is not revenue, expense or profit.
  static Posting transfer({
    required String transferId,
    required String number,
    required DateTime date,
    required String fromCashboxId,
    required String fromName,
    required String toCashboxId,
    required String toName,
    required int amount,
    String? notes,
  }) {
    _requirePositive(amount);
    if (fromCashboxId == toCashboxId) {
      throw const AccountingException(AccountingError.sameCashbox);
    }
    return _validated(Posting(
      type: PostingType.transfer,
      date: date,
      description: _withNotes('تحويل من $fromName إلى $toName', notes),
      sourceCollection: 'transfers',
      sourceId: transferId,
      sourceNumber: number,
      cash: [
        CashMovement(fromCashboxId, -amount),
        CashMovement(toCashboxId, amount),
      ],
    ));
  }

  /// Opening receivable (positive) or customer credit (negative).
  static Posting customerOpening({
    required String customerId,
    required String customerName,
    required DateTime date,
    required int amount,
  }) {
    return _validated(Posting(
      type: PostingType.customerOpening,
      date: date,
      description: 'رصيد افتتاحي',
      sourceCollection: 'customers',
      sourceId: customerId,
      partyName: customerName,
      customers: [
        PartyMovement(
          customerId,
          increase: amount > 0 ? amount : 0,
          decrease: amount < 0 ? -amount : 0,
        ),
      ],
      capital: amount,
    ));
  }

  /// Opening payable (positive) or advance paid to supplier (negative).
  static Posting supplierOpening({
    required String supplierId,
    required String supplierName,
    required DateTime date,
    required int amount,
  }) {
    return _validated(Posting(
      type: PostingType.supplierOpening,
      date: date,
      description: 'رصيد افتتاحي',
      sourceCollection: 'suppliers',
      sourceId: supplierId,
      partyName: supplierName,
      suppliers: [
        PartyMovement(
          supplierId,
          increase: amount > 0 ? amount : 0,
          decrease: amount < 0 ? -amount : 0,
        ),
      ],
      capital: -amount,
    ));
  }

  static Posting cashboxOpening({
    required String cashboxId,
    required String cashboxName,
    required DateTime date,
    required int amount,
  }) {
    return _validated(Posting(
      type: PostingType.cashboxOpening,
      date: date,
      description: 'رصيد افتتاحي - $cashboxName',
      sourceCollection: 'cashboxes',
      sourceId: cashboxId,
      cash: [CashMovement(cashboxId, amount)],
      capital: amount,
    ));
  }

  /// Initial inventory of a product: stock at cost, backed by capital.
  static Posting stockOpening({
    required String productId,
    required String productName,
    required DateTime date,
    required double quantity,
    required int unitCost,
  }) {
    if (!(quantity > 0)) {
      throw const AccountingException(AccountingError.invalidQuantity);
    }
    if (unitCost < 0) throw const AccountingException(AccountingError.negativeAmount);
    final value = (quantity * unitCost).round();
    return _validated(Posting(
      type: PostingType.stockOpening,
      date: date,
      description: 'رصيد افتتاحي للمخزون - $productName',
      sourceCollection: 'products',
      sourceId: productId,
      stock: [
        StockMovement(productId: productId, name: productName, quantity: quantity, value: value),
      ],
      capital: value,
    ));
  }

  /// Stock movements for one sold line of a manufactured product.
  static List<StockMovement> _componentMovements(
    InvoiceLineResult line,
    List<CostedComponent> components,
  ) {
    if (components.isEmpty) {
      throw const AccountingException(AccountingError.emptyRecipe);
    }
    final shares = InvoiceCalculator.allocate(
      line.totalCost,
      [for (final c in components) c.costPerUnit],
    );
    return [
      for (var i = 0; i < components.length; i++)
        StockMovement(
          productId: components[i].productId,
          name: components[i].name,
          quantity: -Recipe.consumed(line.input.quantity, components[i].quantity),
          value: -shares[i],
        ),
    ];
  }

  static void _requirePositive(int amount) {
    if (amount <= 0) throw const AccountingException(AccountingError.zeroAmount);
  }

  static Posting _validated(Posting p) {
    p.validate();
    return p;
  }

  static String _withNotes(String base, String? notes) =>
      (notes == null || notes.trim().isEmpty) ? base : '$base - ${notes.trim()}';
}
