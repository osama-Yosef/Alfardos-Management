import 'package:cloud_firestore/cloud_firestore.dart';

import 'party.dart';

enum PaymentMethod {
  cash('نقداً'),
  bankTransfer('تحويل بنكي'),
  card('بطاقة'),
  wallet('محفظة إلكترونية'),
  cheque('شيك');

  const PaymentMethod(this.label);
  final String label;

  static PaymentMethod parse(String? v) =>
      PaymentMethod.values.firstWhere((e) => e.name == v, orElse: () => cash);
}

/// A receipt from a customer or a payment to a supplier.
class Payment {
  const Payment({
    required this.id,
    required this.kind,
    required this.number,
    required this.date,
    required this.partyId,
    required this.partyName,
    required this.cashboxId,
    required this.cashboxName,
    required this.amount,
    required this.method,
    required this.notes,
    required this.cancelled,
    required this.financialTxId,
    this.createdByName = '',
    this.cancelReason,
  });

  final String id;
  final PartyKind kind;
  final String number;
  final DateTime date;
  final String partyId;
  final String partyName;
  final String cashboxId;
  final String cashboxName;
  final int amount;
  final PaymentMethod method;
  final String notes;
  final bool cancelled;
  final String financialTxId;
  final String createdByName;
  final String? cancelReason;

  factory Payment.fromDoc(PartyKind kind, DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    return Payment(
      id: doc.id,
      kind: kind,
      number: m['number'] as String? ?? '',
      date: (m['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      partyId: m['partyId'] as String? ?? '',
      partyName: m['partyName'] as String? ?? '',
      cashboxId: m['cashboxId'] as String? ?? '',
      cashboxName: m['cashboxName'] as String? ?? '',
      amount: (m['amount'] as num?)?.toInt() ?? 0,
      method: PaymentMethod.parse(m['method'] as String?),
      notes: m['notes'] as String? ?? '',
      cancelled: m['status'] == 'cancelled',
      financialTxId: m['financialTxId'] as String? ?? '',
      createdByName: m['createdByName'] as String? ?? '',
      cancelReason: m['cancelReason'] as String?,
    );
  }
}
