import 'package:cloud_firestore/cloud_firestore.dart';

class ExpenseCategory {
  const ExpenseCategory({required this.id, required this.name, required this.active, this.order = 0});

  final String id;
  final String name;
  final bool active;
  final int order;

  factory ExpenseCategory.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    return ExpenseCategory(
      id: doc.id,
      name: m['name'] as String? ?? '',
      active: m['active'] as bool? ?? true,
      order: (m['order'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  bool operator ==(Object other) => other is ExpenseCategory && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class Expense {
  const Expense({
    required this.id,
    required this.number,
    required this.date,
    required this.categoryId,
    required this.categoryName,
    required this.amount,
    required this.cashboxId,
    required this.cashboxName,
    required this.description,
    required this.cancelled,
    this.attachmentUrl,
    this.createdByName = '',
    this.cancelReason,
  });

  final String id;
  final String number;
  final DateTime date;
  final String categoryId;
  final String categoryName;
  final int amount;
  final String cashboxId;
  final String cashboxName;
  final String description;
  final bool cancelled;
  final String? attachmentUrl;
  final String createdByName;
  final String? cancelReason;

  factory Expense.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    return Expense(
      id: doc.id,
      number: m['number'] as String? ?? '',
      date: (m['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      categoryId: m['categoryId'] as String? ?? '',
      categoryName: m['categoryName'] as String? ?? '',
      amount: (m['amount'] as num?)?.toInt() ?? 0,
      cashboxId: m['cashboxId'] as String? ?? '',
      cashboxName: m['cashboxName'] as String? ?? '',
      description: m['description'] as String? ?? '',
      cancelled: m['status'] == 'cancelled',
      attachmentUrl: m['attachmentUrl'] as String?,
      createdByName: m['createdByName'] as String? ?? '',
      cancelReason: m['cancelReason'] as String?,
    );
  }
}
