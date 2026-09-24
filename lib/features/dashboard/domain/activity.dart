import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/accounting/posting.dart';
import '../../../core/theme/app_colors.dart';

/// A financial transaction as shown in activity feeds and the journal.
class Activity {
  const Activity({
    required this.id,
    required this.type,
    required this.originalType,
    required this.date,
    required this.description,
    required this.amount,
    required this.sourceCollection,
    required this.sourceId,
    this.number,
    this.partyName,
    this.createdByName = '',
    this.createdAt,
    this.metrics = PostingMetrics.zero,
  });

  final String id;
  final PostingType type;
  final PostingType? originalType;
  final DateTime date;
  final String description;
  final int amount;
  final String sourceCollection;
  final String sourceId;
  final String? number;
  final String? partyName;
  final String createdByName;
  final DateTime? createdAt;
  final PostingMetrics metrics;

  PostingType get effective => originalType ?? type;
  bool get isReversal => type == PostingType.reversal;

  factory Activity.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? const {};
    return Activity(
      id: d.id,
      type: PostingType.parse(m['type'] as String),
      originalType: m['originalType'] == null ? null : PostingType.parse(m['originalType'] as String),
      date: (m['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      description: m['description'] as String? ?? '',
      amount: (m['amount'] as num?)?.toInt() ?? 0,
      sourceCollection: m['sourceCollection'] as String? ?? '',
      sourceId: m['sourceId'] as String? ?? '',
      number: m['sourceNumber'] as String?,
      partyName: m['partyName'] as String?,
      createdByName: m['createdByName'] as String? ?? '',
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
      metrics: PostingMetrics.fromMap(m),
    );
  }

  /// In-app route of the business document, if it has a page.
  String? get route => switch (sourceCollection) {
        'sales' => '/sales/$sourceId',
        'purchases' => '/purchases/$sourceId',
        'customers' => '/customers/$sourceId',
        'suppliers' => '/suppliers/$sourceId',
        'cashboxes' => '/cashboxes/$sourceId',
        'customer_payments' => '/receipts',
        'supplier_payments' => '/supplier-payments',
        'expenses' => '/expenses',
        'transfers' => '/transfers',
        'products' => '/products',
        _ => null,
      };

  IconData get icon => switch (effective) {
        PostingType.sale => Symbols.receipt_long,
        PostingType.purchase => Symbols.shopping_cart,
        PostingType.customerPayment => Symbols.call_received,
        PostingType.supplierPayment => Symbols.call_made,
        PostingType.expense => Symbols.payments,
        PostingType.transfer => Symbols.swap_horiz,
        PostingType.stockOpening => Symbols.inventory_2,
        _ => Symbols.account_balance,
      };

  Tone get tone {
    if (isReversal) return Tone.neutral;
    return switch (effective) {
      PostingType.sale || PostingType.customerPayment => Tone.success,
      PostingType.expense => Tone.danger,
      PostingType.purchase || PostingType.supplierPayment => Tone.warning,
      PostingType.transfer => Tone.info,
      _ => Tone.primary,
    };
  }
}
