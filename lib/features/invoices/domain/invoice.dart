import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/accounting/invoice_calculator.dart';
import '../../../core/firebase/collections.dart';
import '../../../core/permissions/permissions.dart';
import '../../parties/domain/party.dart';
import '../../parties/domain/payment.dart';

/// Sales and purchase invoices share one model, form and list; [InvoiceKind]
/// carries what differs.
enum InvoiceKind {
  sale(
    collection: Col.sales,
    counter: Counter.sales,
    partyKind: PartyKind.customer,
    title: 'فاتورة بيع',
    plural: 'المبيعات',
    route: '/sales',
    partyLabel: 'العميل',
    priceLabel: 'سعر البيع',
    view: Permission.viewSales,
    create: Permission.createSales,
    cancel: Permission.cancelSales,
  ),
  purchase(
    collection: Col.purchases,
    counter: Counter.purchases,
    partyKind: PartyKind.supplier,
    title: 'فاتورة شراء',
    plural: 'المشتريات',
    route: '/purchases',
    partyLabel: 'المورد',
    priceLabel: 'سعر الشراء',
    view: Permission.viewPurchases,
    create: Permission.createPurchases,
    cancel: Permission.cancelPurchases,
  );

  const InvoiceKind({
    required this.collection,
    required this.counter,
    required this.partyKind,
    required this.title,
    required this.plural,
    required this.route,
    required this.partyLabel,
    required this.priceLabel,
    required this.view,
    required this.create,
    required this.cancel,
  });

  final String collection;
  final Counter counter;
  final PartyKind partyKind;
  final String title;
  final String plural;
  final String route;
  final String partyLabel;
  final String priceLabel;
  final Permission view;
  final Permission create;
  final Permission cancel;

  bool get isSale => this == sale;

  /// Label for an invoice without a registered party.
  String get walkInLabel => isSale ? 'عميل نقدي' : 'مورد نقدي';
}

class InvoiceLine {
  const InvoiceLine({
    required this.kind,
    required this.itemId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.unitCost,
    required this.gross,
    required this.discountShare,
    required this.cost,
  });

  final LineKind kind;
  final String itemId;
  final String name;
  final double quantity;
  final int unitPrice;
  final int unitCost;
  final int gross;
  final int discountShare;
  final int cost;

  int get net => gross - discountShare;
  int get profit => net - cost;

  factory InvoiceLine.fromResult(InvoiceLineResult r) => InvoiceLine(
        kind: r.input.kind,
        itemId: r.input.itemId,
        name: r.input.name,
        quantity: r.input.quantity,
        unitPrice: r.input.unitPrice,
        unitCost: r.input.unitCost,
        gross: r.grossTotal,
        discountShare: r.discountShare,
        cost: r.totalCost,
      );

  Map<String, dynamic> toMap() => {
        'kind': kind.name,
        'itemId': itemId,
        'name': name,
        'qty': quantity,
        'unitPrice': unitPrice,
        'unitCost': unitCost,
        'gross': gross,
        'discountShare': discountShare,
        'net': net,
        'cost': cost,
      };

  factory InvoiceLine.fromMap(Map<String, dynamic> m) => InvoiceLine(
        kind: LineKind.parse(m['kind'] as String? ?? 'product'),
        itemId: m['itemId'] as String? ?? '',
        name: m['name'] as String? ?? '',
        quantity: (m['qty'] as num?)?.toDouble() ?? 0,
        unitPrice: (m['unitPrice'] as num?)?.toInt() ?? 0,
        unitCost: (m['unitCost'] as num?)?.toInt() ?? 0,
        gross: (m['gross'] as num?)?.toInt() ?? 0,
        discountShare: (m['discountShare'] as num?)?.toInt() ?? 0,
        cost: (m['cost'] as num?)?.toInt() ?? 0,
      );
}

class Invoice {
  const Invoice({
    required this.id,
    required this.kind,
    required this.number,
    required this.date,
    required this.partyId,
    required this.partyName,
    required this.cashboxId,
    required this.cashboxName,
    required this.method,
    required this.lines,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.paid,
    required this.productCost,
    required this.serviceCost,
    required this.cancelled,
    required this.notes,
    required this.financialTxId,
    this.createdByName = '',
    this.createdAt,
    this.cancelReason,
    this.cancelledByName,
  });

  final String id;
  final InvoiceKind kind;
  final String number;
  final DateTime date;
  final String? partyId;
  final String partyName;
  final String? cashboxId;
  final String cashboxName;
  final PaymentMethod method;
  final List<InvoiceLine> lines;
  final int subtotal;
  final int discount;
  final int total;
  final int paid;
  final int productCost;
  final int serviceCost;
  final bool cancelled;
  final String notes;
  final String financialTxId;
  final String createdByName;
  final DateTime? createdAt;
  final String? cancelReason;
  final String? cancelledByName;

  int get remaining => total - paid;
  int get totalCost => productCost + serviceCost;
  int get grossProfit => total - totalCost;
  PaymentStatus get paymentStatus => PaymentStatus.of(total: total, paid: paid);

  factory Invoice.fromDoc(InvoiceKind kind, DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    int i(String k) => (m[k] as num?)?.toInt() ?? 0;
    return Invoice(
      id: doc.id,
      kind: kind,
      number: m['number'] as String? ?? '',
      date: (m['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      partyId: m['partyId'] as String?,
      partyName: m['partyName'] as String? ?? kind.walkInLabel,
      cashboxId: m['cashboxId'] as String?,
      cashboxName: m['cashboxName'] as String? ?? '',
      method: PaymentMethod.parse(m['method'] as String?),
      lines: ((m['lines'] as List?) ?? const [])
          .map((e) => InvoiceLine.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      subtotal: i('subtotal'),
      discount: i('discount'),
      total: i('total'),
      paid: i('paid'),
      productCost: i('productCost'),
      serviceCost: i('serviceCost'),
      cancelled: m['status'] == 'cancelled',
      notes: m['notes'] as String? ?? '',
      financialTxId: m['financialTxId'] as String? ?? '',
      createdByName: m['createdByName'] as String? ?? '',
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
      cancelReason: m['cancelReason'] as String?,
      cancelledByName: m['cancelledByName'] as String?,
    );
  }
}

/// What the invoice form submits. For sales, product unit costs are NOT
/// taken from here: the repository reads the current average cost inside
/// the posting transaction.
class InvoiceSubmission {
  const InvoiceSubmission({
    required this.kind,
    required this.postingId,
    required this.date,
    required this.lines,
    required this.discount,
    required this.paid,
    required this.method,
    required this.notes,
    this.party,
    this.cashboxId,
    this.cashboxName,
  });

  final InvoiceKind kind;
  final String postingId;
  final DateTime date;
  final List<InvoiceLineInput> lines;
  final int discount;
  final int paid;
  final PaymentMethod method;
  final String notes;
  final Party? party;
  final String? cashboxId;
  final String? cashboxName;
}
