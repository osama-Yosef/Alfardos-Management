import 'accounting_exception.dart';

/// The kind of business operation a [Posting] records.
enum PostingType {
  sale('فاتورة بيع'),
  purchase('فاتورة شراء'),
  customerPayment('تحصيل من عميل'),
  supplierPayment('دفع لمورد'),
  expense('مصروف'),
  transfer('تحويل بين الخزائن'),
  customerOpening('رصيد افتتاحي لعميل'),
  supplierOpening('رصيد افتتاحي لمورد'),
  cashboxOpening('رصيد افتتاحي لخزنة'),
  stockOpening('رصيد افتتاحي لمخزون'),
  reversal('قيد إلغاء');

  const PostingType(this.label);
  final String label;

  static PostingType parse(String value) =>
      PostingType.values.firstWhere((e) => e.name == value);

  /// Movements that are not operational cash flow (internal moves and
  /// opening balances) are excluded from cash-in/cash-out statistics.
  bool get countsAsCashFlow =>
      this != transfer &&
      this != customerOpening &&
      this != supplierOpening &&
      this != cashboxOpening &&
      this != stockOpening;
}

/// Change of a cashbox balance. Positive = money in.
class CashMovement {
  const CashMovement(this.cashboxId, this.amount);
  final String cashboxId;
  final int amount;

  CashMovement negate() => CashMovement(cashboxId, -amount);
  Map<String, dynamic> toMap() => {'id': cashboxId, 'amount': amount};
  factory CashMovement.fromMap(Map<String, dynamic> m) =>
      CashMovement(m['id'] as String, (m['amount'] as num).toInt());
}

/// Change of a customer receivable or supplier payable.
///
/// [increase] raises the balance (customer owes more / we owe the supplier
/// more) and [decrease] lowers it. Keeping both sides (instead of a single
/// net amount) lets statements show a sale of 10,000 with 3,000 paid on the
/// spot as a debit and a credit, exactly like a paper ledger.
class PartyMovement {
  const PartyMovement(
    this.partyId, {
    this.increase = 0,
    this.decrease = 0,
    this.enforceNonNegative = false,
  });

  final String partyId;
  final int increase;
  final int decrease;

  /// When true the resulting balance must not drop below zero unless the
  /// company settings allow over-payment (used by payments).
  final bool enforceNonNegative;

  int get amount => increase - decrease;

  PartyMovement negate() =>
      PartyMovement(partyId, increase: decrease, decrease: increase);

  Map<String, dynamic> toMap() =>
      {'id': partyId, 'increase': increase, 'decrease': decrease};

  factory PartyMovement.fromMap(Map<String, dynamic> m) => PartyMovement(
        m['id'] as String,
        increase: (m['increase'] as num?)?.toInt() ?? 0,
        decrease: (m['decrease'] as num?)?.toInt() ?? 0,
      );
}

/// Change of product stock. [value] is the signed inventory value moved
/// (minor units), so inventory valuation stays exact after discounts.
class StockMovement {
  const StockMovement({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.value,
    this.revaluesCost = false,
  });

  final String productId;
  final String name;
  final double quantity;
  final int value;

  /// Outbound movements normally leave the average cost unchanged. A purchase
  /// reversal removes goods *at their purchase cost* and must re-average.
  final bool revaluesCost;

  StockMovement negate({bool? revaluesCost}) => StockMovement(
        productId: productId,
        name: name,
        quantity: -quantity,
        value: -value,
        revaluesCost: revaluesCost ?? this.revaluesCost,
      );

  Map<String, dynamic> toMap() => {
        'id': productId,
        'name': name,
        'qty': quantity,
        'value': value,
        'revalue': revaluesCost,
      };

  factory StockMovement.fromMap(Map<String, dynamic> m) => StockMovement(
        productId: m['id'] as String,
        name: m['name'] as String? ?? '',
        quantity: (m['qty'] as num).toDouble(),
        value: (m['value'] as num).toInt(),
        revaluesCost: m['revalue'] as bool? ?? false,
      );
}

/// Operational statistics of a posting. These are the numbers the dashboard
/// and reports aggregate. A reversal carries the exact negation, so summing
/// any date range always yields correct net figures.
class PostingMetrics {
  const PostingMetrics({
    this.sales = 0,
    this.serviceRevenue = 0,
    this.productCost = 0,
    this.serviceCost = 0,
    this.expenses = 0,
    this.purchases = 0,
    this.cashIn = 0,
    this.cashOut = 0,
    this.customerReceipts = 0,
    this.supplierPayments = 0,
    this.salesCount = 0,
  });

  /// Net sales revenue after discount (products + services).
  final int sales;
  final int serviceRevenue;
  final int productCost;
  final int serviceCost;
  final int expenses;
  final int purchases;
  final int cashIn;

  /// Stored as a positive number.
  final int cashOut;
  final int customerReceipts;
  final int supplierPayments;
  final int salesCount;

  int get grossProfit => sales - productCost - serviceCost;
  int get netProfit => grossProfit - expenses;

  static const fields = [
    'sales',
    'serviceRevenue',
    'productCost',
    'serviceCost',
    'expenses',
    'purchases',
    'cashIn',
    'cashOut',
    'customerReceipts',
    'supplierPayments',
    'salesCount',
  ];

  Map<String, int> toMap() => {
        'sales': sales,
        'serviceRevenue': serviceRevenue,
        'productCost': productCost,
        'serviceCost': serviceCost,
        'expenses': expenses,
        'purchases': purchases,
        'cashIn': cashIn,
        'cashOut': cashOut,
        'customerReceipts': customerReceipts,
        'supplierPayments': supplierPayments,
        'salesCount': salesCount,
      };

  factory PostingMetrics.fromMap(Map<String, dynamic> m) {
    int v(String k) => (m[k] as num?)?.toInt() ?? 0;
    return PostingMetrics(
      sales: v('sales'),
      serviceRevenue: v('serviceRevenue'),
      productCost: v('productCost'),
      serviceCost: v('serviceCost'),
      expenses: v('expenses'),
      purchases: v('purchases'),
      cashIn: v('cashIn'),
      cashOut: v('cashOut'),
      customerReceipts: v('customerReceipts'),
      supplierPayments: v('supplierPayments'),
      salesCount: v('salesCount'),
    );
  }

  PostingMetrics operator +(PostingMetrics o) => PostingMetrics(
        sales: sales + o.sales,
        serviceRevenue: serviceRevenue + o.serviceRevenue,
        productCost: productCost + o.productCost,
        serviceCost: serviceCost + o.serviceCost,
        expenses: expenses + o.expenses,
        purchases: purchases + o.purchases,
        cashIn: cashIn + o.cashIn,
        cashOut: cashOut + o.cashOut,
        customerReceipts: customerReceipts + o.customerReceipts,
        supplierPayments: supplierPayments + o.supplierPayments,
        salesCount: salesCount + o.salesCount,
      );

  PostingMetrics negate() => PostingMetrics(
        sales: -sales,
        serviceRevenue: -serviceRevenue,
        productCost: -productCost,
        serviceCost: -serviceCost,
        expenses: -expenses,
        purchases: -purchases,
        cashIn: -cashIn,
        cashOut: -cashOut,
        customerReceipts: -customerReceipts,
        supplierPayments: -supplierPayments,
        salesCount: -salesCount,
      );

  static const zero = PostingMetrics();
}

/// A complete, self-describing accounting entry for one business operation.
///
/// Every financial operation in the application is expressed as a Posting and
/// written by the ledger service in a single atomic Firestore transaction:
/// the financial transaction record, one sub-ledger record per affected
/// cashbox / customer / supplier, the balance updates, stock updates and the
/// daily statistics. Postings are immutable; cancellation is a new posting
/// produced by [reversed].
///
/// Double-entry check ([isBalanced]):
///   Δcash + Δreceivables + Δinventory − Δpayables − accrued service cost
///     == net profit effect + capital (opening balances)
class Posting {
  Posting({
    required this.type,
    required this.date,
    required this.description,
    required this.sourceCollection,
    required this.sourceId,
    this.sourceNumber,
    this.partyName,
    this.cash = const [],
    this.customers = const [],
    this.suppliers = const [],
    this.stock = const [],
    this.metrics = PostingMetrics.zero,
    this.capital = 0,
    this.reversalOf,
    this.originalType,
  });

  final PostingType type;
  final DateTime date;
  final String description;

  /// The business document this posting belongs to (e.g. `sales/abc`).
  final String sourceCollection;
  final String sourceId;
  final String? sourceNumber;

  /// Display name of the customer/supplier, for activity feeds.
  final String? partyName;

  final List<CashMovement> cash;
  final List<PartyMovement> customers;
  final List<PartyMovement> suppliers;
  final List<StockMovement> stock;
  final PostingMetrics metrics;

  /// Owner's equity introduced by opening balances.
  final int capital;

  /// Id of the financial transaction this posting reverses.
  final String? reversalOf;
  final PostingType? originalType;

  PostingType get effectiveType => originalType ?? type;

  int get cashDelta => cash.fold(0, (s, m) => s + m.amount);
  int get receivableDelta => customers.fold(0, (s, m) => s + m.amount);
  int get payableDelta => suppliers.fold(0, (s, m) => s + m.amount);
  int get inventoryDelta => stock.fold(0, (s, m) => s + m.value);

  bool get isBalanced =>
      cashDelta + receivableDelta + inventoryDelta - payableDelta - metrics.serviceCost ==
      metrics.netProfit + capital;

  /// Validates structural invariants; throws [AccountingException].
  void validate() {
    if (!isBalanced) {
      throw const AccountingException(AccountingError.unbalancedPosting);
    }
    _requireUnique(cash.map((m) => m.cashboxId));
    _requireUnique(customers.map((m) => m.partyId));
    _requireUnique(suppliers.map((m) => m.partyId));
  }

  static void _requireUnique(Iterable<String> ids) {
    final list = ids.toList();
    if (list.toSet().length != list.length) {
      // The ledger applies at most one movement per account per posting so
      // every sub-ledger record maps to exactly one balance update.
      throw const AccountingException(AccountingError.unbalancedPosting);
    }
  }

  /// Builds the cancellation entry: every movement and metric negated.
  Posting reversed({
    required String reversalOfId,
    required DateTime date,
    required String description,
  }) {
    if (type == PostingType.reversal) {
      throw const AccountingException(AccountingError.cannotReverseReversal);
    }
    return Posting(
      type: PostingType.reversal,
      originalType: type,
      reversalOf: reversalOfId,
      date: date,
      description: description,
      sourceCollection: sourceCollection,
      sourceId: sourceId,
      sourceNumber: sourceNumber,
      partyName: partyName,
      cash: [for (final m in cash) m.negate()],
      customers: [for (final m in customers) m.negate()],
      suppliers: [for (final m in suppliers) m.negate()],
      // Undoing a purchase removes goods at their purchase cost (re-average);
      // undoing a sale returns goods at their original cost (averaged in).
      stock: [
        for (final m in stock) m.negate(revaluesCost: type == PostingType.purchase),
      ],
      metrics: metrics.negate(),
      capital: -capital,
    );
  }

  Map<String, dynamic> movementsToMap() => {
        'cash': [for (final m in cash) m.toMap()],
        'customers': [for (final m in customers) m.toMap()],
        'suppliers': [for (final m in suppliers) m.toMap()],
        'stock': [for (final m in stock) m.toMap()],
      };

  /// Rebuilds a posting from a stored financial transaction document.
  factory Posting.fromMap(Map<String, dynamic> m, DateTime date) {
    List<Map<String, dynamic>> list(String key) =>
        ((m[key] as List?) ?? const []).cast<Map<String, dynamic>>();
    return Posting(
      type: PostingType.parse(m['type'] as String),
      originalType: m['originalType'] == null
          ? null
          : PostingType.parse(m['originalType'] as String),
      reversalOf: m['reversalOf'] as String?,
      date: date,
      description: m['description'] as String? ?? '',
      sourceCollection: m['sourceCollection'] as String,
      sourceId: m['sourceId'] as String,
      sourceNumber: m['sourceNumber'] as String?,
      partyName: m['partyName'] as String?,
      cash: list('cash').map(CashMovement.fromMap).toList(),
      customers: list('customers').map(PartyMovement.fromMap).toList(),
      suppliers: list('suppliers').map(PartyMovement.fromMap).toList(),
      stock: list('stock').map(StockMovement.fromMap).toList(),
      metrics: PostingMetrics.fromMap(m),
      capital: (m['capital'] as num?)?.toInt() ?? 0,
    );
  }
}
