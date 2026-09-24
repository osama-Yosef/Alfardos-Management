import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/accounting/invoice_calculator.dart';

/// A stock-tracked product. [costPrice] is the current weighted-average cost,
/// maintained by the ledger on every purchase/sale.
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.sellPrice,
    required this.costPrice,
    required this.stockQty,
    required this.active,
    this.sku = '',
    this.barcode = '',
    this.unit = 'قطعة',
    this.lowStockAlert = 0,
    this.description = '',
  });

  final String id;
  final String name;
  final String sku;
  final String barcode;
  final String unit;
  final int sellPrice;
  final int costPrice;
  final double stockQty;
  final double lowStockAlert;
  final bool active;
  final String description;

  bool get isLowStock => lowStockAlert > 0 && stockQty <= lowStockAlert;

  factory Product.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    return Product(
      id: doc.id,
      name: m['name'] as String? ?? '',
      sku: m['sku'] as String? ?? '',
      barcode: m['barcode'] as String? ?? '',
      unit: m['unit'] as String? ?? 'قطعة',
      sellPrice: (m['sellPrice'] as num?)?.toInt() ?? 0,
      costPrice: (m['costPrice'] as num?)?.toInt() ?? 0,
      stockQty: (m['stockQty'] as num?)?.toDouble() ?? 0,
      lowStockAlert: (m['lowStockAlert'] as num?)?.toDouble() ?? 0,
      active: m['active'] as bool? ?? true,
      description: m['description'] as String? ?? '',
    );
  }
}

/// A sellable service with a configured cost (e.g. installation).
class ServiceItem {
  const ServiceItem({
    required this.id,
    required this.name,
    required this.sellPrice,
    required this.cost,
    required this.active,
    this.description = '',
  });

  final String id;
  final String name;
  final int sellPrice;
  final int cost;
  final bool active;
  final String description;

  int get profit => sellPrice - cost;
  double get margin => sellPrice == 0 ? 0 : profit / sellPrice;

  factory ServiceItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    return ServiceItem(
      id: doc.id,
      name: m['name'] as String? ?? '',
      sellPrice: (m['sellPrice'] as num?)?.toInt() ?? 0,
      cost: (m['cost'] as num?)?.toInt() ?? 0,
      active: m['active'] as bool? ?? true,
      description: m['description'] as String? ?? '',
    );
  }
}

/// Anything that can be put on an invoice line.
class Sellable {
  const Sellable({
    required this.kind,
    required this.id,
    required this.name,
    required this.price,
    required this.cost,
    this.stockQty,
    this.unit = '',
  });

  factory Sellable.product(Product p) => Sellable(
        kind: LineKind.product,
        id: p.id,
        name: p.name,
        price: p.sellPrice,
        cost: p.costPrice,
        stockQty: p.stockQty,
        unit: p.unit,
      );

  factory Sellable.service(ServiceItem s) => Sellable(
        kind: LineKind.service,
        id: s.id,
        name: s.name,
        price: s.sellPrice,
        cost: s.cost,
      );

  final LineKind kind;
  final String id;
  final String name;
  final int price;
  final int cost;
  final double? stockQty;
  final String unit;
}
