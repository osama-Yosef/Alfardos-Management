import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firebase/collections.dart';
import '../../../core/permissions/permissions.dart';

/// Customers and suppliers share one model and one implementation; the
/// [PartyKind] carries everything that differs (collections, labels,
/// permissions, statement column meaning).
enum PartyKind {
  customer(
    collection: Col.customers,
    txCollection: Col.customerTransactions,
    paymentCollection: Col.customerPayments,
    idField: 'customerId',
    singular: 'عميل',
    plural: 'العملاء',
    route: '/customers',
    balanceLabel: 'الرصيد المستحق على العميل',
    increaseLabel: 'مدين',
    decreaseLabel: 'دائن',
    totalIncreaseLabel: 'إجمالي المبيعات',
    totalDecreaseLabel: 'إجمالي المدفوعات',
    paymentTitle: 'تحصيل من عميل',
    view: Permission.viewCustomers,
    manage: Permission.manageCustomers,
    pay: Permission.createPayment,
  ),
  supplier(
    collection: Col.suppliers,
    txCollection: Col.supplierTransactions,
    paymentCollection: Col.supplierPayments,
    idField: 'supplierId',
    singular: 'مورد',
    plural: 'الموردون',
    route: '/suppliers',
    balanceLabel: 'المستحق للمورد',
    increaseLabel: 'دائن',
    decreaseLabel: 'مدين',
    totalIncreaseLabel: 'إجمالي المشتريات',
    totalDecreaseLabel: 'إجمالي المدفوعات',
    paymentTitle: 'دفع لمورد',
    view: Permission.viewSuppliers,
    manage: Permission.manageSuppliers,
    pay: Permission.createSupplierPayment,
  );

  const PartyKind({
    required this.collection,
    required this.txCollection,
    required this.paymentCollection,
    required this.idField,
    required this.singular,
    required this.plural,
    required this.route,
    required this.balanceLabel,
    required this.increaseLabel,
    required this.decreaseLabel,
    required this.totalIncreaseLabel,
    required this.totalDecreaseLabel,
    required this.paymentTitle,
    required this.view,
    required this.manage,
    required this.pay,
  });

  final String collection;
  final String txCollection;
  final String paymentCollection;
  final String idField;
  final String singular;
  final String plural;
  final String route;
  final String balanceLabel;

  /// Statement column for movements that raise the balance
  /// (customer: debit / supplier: credit).
  final String increaseLabel;
  final String decreaseLabel;
  final String totalIncreaseLabel;
  final String totalDecreaseLabel;
  final String paymentTitle;
  final Permission view;
  final Permission manage;
  final Permission pay;

  bool get isCustomer => this == customer;
}

class Party {
  const Party({
    required this.id,
    required this.kind,
    required this.name,
    this.phone = '',
    this.address = '',
    this.notes = '',
    this.balance = 0,
    this.openingBalance = 0,
    this.totalIncrease = 0,
    this.totalDecrease = 0,
    this.invoiceCount = 0,
    this.lastTxAt,
    this.active = true,
    this.createdAt,
  });

  final String id;
  final PartyKind kind;
  final String name;
  final String phone;
  final String address;
  final String notes;

  /// Customer: amount the customer owes us. Supplier: amount we owe.
  /// Maintained atomically by the ledger alongside sub-ledger records.
  final int balance;
  final int openingBalance;
  final int totalIncrease;
  final int totalDecrease;
  final int invoiceCount;
  final DateTime? lastTxAt;
  final bool active;
  final DateTime? createdAt;

  factory Party.fromDoc(PartyKind kind, DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    int i(String k) => (m[k] as num?)?.toInt() ?? 0;
    return Party(
      id: doc.id,
      kind: kind,
      name: m['name'] as String? ?? '',
      phone: m['phone'] as String? ?? '',
      address: m['address'] as String? ?? '',
      notes: m['notes'] as String? ?? '',
      balance: i('balance'),
      openingBalance: i('openingBalance'),
      totalIncrease: i('totalIncrease'),
      totalDecrease: i('totalDecrease'),
      invoiceCount: i('invoiceCount'),
      lastTxAt: (m['lastTxAt'] as Timestamp?)?.toDate(),
      active: m['active'] as bool? ?? true,
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// Editable fields of a party.
class PartyInput {
  const PartyInput({
    required this.name,
    this.phone = '',
    this.address = '',
    this.notes = '',
  });

  final String name;
  final String phone;
  final String address;
  final String notes;

  Map<String, dynamic> toMap() => {
        'name': name.trim(),
        'phone': phone.trim(),
        'address': address.trim(),
        'notes': notes.trim(),
      };
}
