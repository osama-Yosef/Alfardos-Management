import '../firebase/collections.dart';

/// Business-wide configuration stored in `settings/company`.
class CompanySettings {
  const CompanySettings({
    this.companyName = 'شركتي',
    this.logoUrl,
    this.phone = '',
    this.address = '',
    this.taxNumber = '',
    this.currencyCode = 'USD',
    this.currencySymbol = '\$',
    this.decimals = 2,
    this.invoicePrefix = 'INV-',
    this.purchasePrefix = 'PUR-',
    this.receiptPrefix = 'REC-',
    this.paymentPrefix = 'PAY-',
    this.expensePrefix = 'EXP-',
    this.transferPrefix = 'TRF-',
    this.defaultCashboxId,
    this.allowNegativeCash = false,
    this.allowNegativeStock = true,
    this.allowCustomerOverpayment = false,
    this.allowSupplierOverpayment = false,
    this.lowCashThreshold = 0,
    this.largeExpenseThreshold = 0,
    this.invoiceFooter = 'شكراً لتعاملكم معنا',
    this.showCostOnInvoice = false,
    this.paperSize = PaperSize.a4,
    this.taxEnabled = false,
    this.taxRatePercent = 0,
  });

  final String companyName;
  final String? logoUrl;
  final String phone;
  final String address;
  final String taxNumber;
  final String currencyCode;
  final String currencySymbol;
  final int decimals;
  final String invoicePrefix;
  final String purchasePrefix;
  final String receiptPrefix;
  final String paymentPrefix;
  final String expensePrefix;
  final String transferPrefix;
  final String? defaultCashboxId;

  /// Business rules enforced by the ledger service and security rules.
  final bool allowNegativeCash;
  final bool allowNegativeStock;
  final bool allowCustomerOverpayment;
  final bool allowSupplierOverpayment;

  /// Alert thresholds (minor units). 0 disables the alert.
  final int lowCashThreshold;
  final int largeExpenseThreshold;

  final String invoiceFooter;
  final bool showCostOnInvoice;
  final PaperSize paperSize;

  /// Reserved for a future tax module; stored so settings UI is complete.
  final bool taxEnabled;
  final double taxRatePercent;

  String prefixFor(Counter counter) => switch (counter) {
        Counter.sales => invoicePrefix,
        Counter.purchases => purchasePrefix,
        Counter.customerPayments => receiptPrefix,
        Counter.supplierPayments => paymentPrefix,
        Counter.expenses => expensePrefix,
        Counter.transfers => transferPrefix,
      };

  factory CompanySettings.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const CompanySettings();
    const d = CompanySettings();
    int i(String k, int def) => (m[k] as num?)?.toInt() ?? def;
    return CompanySettings(
      companyName: m['companyName'] as String? ?? d.companyName,
      logoUrl: m['logoUrl'] as String?,
      phone: m['phone'] as String? ?? '',
      address: m['address'] as String? ?? '',
      taxNumber: m['taxNumber'] as String? ?? '',
      currencyCode: m['currencyCode'] as String? ?? d.currencyCode,
      currencySymbol: m['currencySymbol'] as String? ?? d.currencySymbol,
      decimals: i('decimals', 2),
      invoicePrefix: m['invoicePrefix'] as String? ?? d.invoicePrefix,
      purchasePrefix: m['purchasePrefix'] as String? ?? d.purchasePrefix,
      receiptPrefix: m['receiptPrefix'] as String? ?? d.receiptPrefix,
      paymentPrefix: m['paymentPrefix'] as String? ?? d.paymentPrefix,
      expensePrefix: m['expensePrefix'] as String? ?? d.expensePrefix,
      transferPrefix: m['transferPrefix'] as String? ?? d.transferPrefix,
      defaultCashboxId: m['defaultCashboxId'] as String?,
      allowNegativeCash: m['allowNegativeCash'] as bool? ?? false,
      allowNegativeStock: m['allowNegativeStock'] as bool? ?? true,
      allowCustomerOverpayment: m['allowCustomerOverpayment'] as bool? ?? false,
      allowSupplierOverpayment: m['allowSupplierOverpayment'] as bool? ?? false,
      lowCashThreshold: i('lowCashThreshold', 0),
      largeExpenseThreshold: i('largeExpenseThreshold', 0),
      invoiceFooter: m['invoiceFooter'] as String? ?? d.invoiceFooter,
      showCostOnInvoice: m['showCostOnInvoice'] as bool? ?? false,
      paperSize: PaperSize.parse(m['paperSize'] as String?),
      taxEnabled: m['taxEnabled'] as bool? ?? false,
      taxRatePercent: (m['taxRatePercent'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'companyName': companyName,
        'logoUrl': logoUrl,
        'phone': phone,
        'address': address,
        'taxNumber': taxNumber,
        'currencyCode': currencyCode,
        'currencySymbol': currencySymbol,
        'decimals': decimals,
        'invoicePrefix': invoicePrefix,
        'purchasePrefix': purchasePrefix,
        'receiptPrefix': receiptPrefix,
        'paymentPrefix': paymentPrefix,
        'expensePrefix': expensePrefix,
        'transferPrefix': transferPrefix,
        'defaultCashboxId': defaultCashboxId,
        'allowNegativeCash': allowNegativeCash,
        'allowNegativeStock': allowNegativeStock,
        'allowCustomerOverpayment': allowCustomerOverpayment,
        'allowSupplierOverpayment': allowSupplierOverpayment,
        'lowCashThreshold': lowCashThreshold,
        'largeExpenseThreshold': largeExpenseThreshold,
        'invoiceFooter': invoiceFooter,
        'showCostOnInvoice': showCostOnInvoice,
        'paperSize': paperSize.name,
        'taxEnabled': taxEnabled,
        'taxRatePercent': taxRatePercent,
      };

  CompanySettings copyWith({
    String? companyName,
    String? logoUrl,
    bool clearLogo = false,
    String? phone,
    String? address,
    String? taxNumber,
    String? currencyCode,
    String? currencySymbol,
    int? decimals,
    String? invoicePrefix,
    String? purchasePrefix,
    String? receiptPrefix,
    String? paymentPrefix,
    String? expensePrefix,
    String? transferPrefix,
    String? defaultCashboxId,
    bool? allowNegativeCash,
    bool? allowNegativeStock,
    bool? allowCustomerOverpayment,
    bool? allowSupplierOverpayment,
    int? lowCashThreshold,
    int? largeExpenseThreshold,
    String? invoiceFooter,
    bool? showCostOnInvoice,
    PaperSize? paperSize,
    bool? taxEnabled,
    double? taxRatePercent,
  }) =>
      CompanySettings(
        companyName: companyName ?? this.companyName,
        logoUrl: clearLogo ? null : (logoUrl ?? this.logoUrl),
        phone: phone ?? this.phone,
        address: address ?? this.address,
        taxNumber: taxNumber ?? this.taxNumber,
        currencyCode: currencyCode ?? this.currencyCode,
        currencySymbol: currencySymbol ?? this.currencySymbol,
        decimals: decimals ?? this.decimals,
        invoicePrefix: invoicePrefix ?? this.invoicePrefix,
        purchasePrefix: purchasePrefix ?? this.purchasePrefix,
        receiptPrefix: receiptPrefix ?? this.receiptPrefix,
        paymentPrefix: paymentPrefix ?? this.paymentPrefix,
        expensePrefix: expensePrefix ?? this.expensePrefix,
        transferPrefix: transferPrefix ?? this.transferPrefix,
        defaultCashboxId: defaultCashboxId ?? this.defaultCashboxId,
        allowNegativeCash: allowNegativeCash ?? this.allowNegativeCash,
        allowNegativeStock: allowNegativeStock ?? this.allowNegativeStock,
        allowCustomerOverpayment: allowCustomerOverpayment ?? this.allowCustomerOverpayment,
        allowSupplierOverpayment: allowSupplierOverpayment ?? this.allowSupplierOverpayment,
        lowCashThreshold: lowCashThreshold ?? this.lowCashThreshold,
        largeExpenseThreshold: largeExpenseThreshold ?? this.largeExpenseThreshold,
        invoiceFooter: invoiceFooter ?? this.invoiceFooter,
        showCostOnInvoice: showCostOnInvoice ?? this.showCostOnInvoice,
        paperSize: paperSize ?? this.paperSize,
        taxEnabled: taxEnabled ?? this.taxEnabled,
        taxRatePercent: taxRatePercent ?? this.taxRatePercent,
      );
}

enum PaperSize {
  a4('A4'),
  receipt80('إيصال 80 مم');

  const PaperSize(this.label);
  final String label;

  static PaperSize parse(String? v) =>
      PaperSize.values.firstWhere((e) => e.name == v, orElse: () => a4);
}
