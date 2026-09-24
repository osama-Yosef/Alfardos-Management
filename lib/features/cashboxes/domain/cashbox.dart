import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

enum CashboxKind {
  cash('خزنة نقدية', Symbols.payments),
  bank('حساب بنكي', Symbols.account_balance),
  wallet('محفظة إلكترونية', Symbols.account_balance_wallet);

  const CashboxKind(this.label, this.icon);
  final String label;
  final IconData icon;

  static CashboxKind parse(String? v) =>
      CashboxKind.values.firstWhere((e) => e.name == v, orElse: () => cash);
}

class Cashbox {
  const Cashbox({
    required this.id,
    required this.name,
    required this.kind,
    required this.balance,
    required this.totalIn,
    required this.totalOut,
    required this.active,
    this.notes = '',
    this.lastTxAt,
  });

  final String id;
  final String name;
  final CashboxKind kind;

  /// Maintained atomically by the ledger; each change is linked to the
  /// cash transaction that caused it (verified by security rules).
  final int balance;
  final int totalIn;
  final int totalOut;
  final bool active;
  final String notes;
  final DateTime? lastTxAt;

  factory Cashbox.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    int i(String k) => (m[k] as num?)?.toInt() ?? 0;
    return Cashbox(
      id: doc.id,
      name: m['name'] as String? ?? '',
      kind: CashboxKind.parse(m['kind'] as String?),
      balance: i('balance'),
      totalIn: i('totalIn'),
      totalOut: i('totalOut'),
      active: m['active'] as bool? ?? true,
      notes: m['notes'] as String? ?? '',
      lastTxAt: (m['lastTxAt'] as Timestamp?)?.toDate(),
    );
  }

  @override
  bool operator ==(Object other) => other is Cashbox && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class Transfer {
  const Transfer({
    required this.id,
    required this.number,
    required this.date,
    required this.fromId,
    required this.fromName,
    required this.toId,
    required this.toName,
    required this.amount,
    required this.notes,
    required this.cancelled,
    this.createdByName = '',
  });

  final String id;
  final String number;
  final DateTime date;
  final String fromId;
  final String fromName;
  final String toId;
  final String toName;
  final int amount;
  final String notes;
  final bool cancelled;
  final String createdByName;

  factory Transfer.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    return Transfer(
      id: doc.id,
      number: m['number'] as String? ?? '',
      date: (m['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      fromId: m['fromId'] as String? ?? '',
      fromName: m['fromName'] as String? ?? '',
      toId: m['toId'] as String? ?? '',
      toName: m['toName'] as String? ?? '',
      amount: (m['amount'] as num?)?.toInt() ?? 0,
      notes: m['notes'] as String? ?? '',
      cancelled: m['status'] == 'cancelled',
      createdByName: m['createdByName'] as String? ?? '',
    );
  }
}
