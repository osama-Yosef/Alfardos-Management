import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

enum ReportType {
  profit('profit', 'تقرير الأرباح', 'الإيرادات − تكلفة البضاعة − تكلفة الخدمات − المصروفات', Symbols.monitoring),
  sales('sales', 'تقرير المبيعات', 'النقدي والآجل والمدفوع والمتبقي والتكلفة والربح', Symbols.receipt_long),
  purchases('purchases', 'تقرير المشتريات', 'إجمالي المشتريات والمدفوع والمتبقي', Symbols.shopping_cart),
  expenses('expenses', 'تقرير المصروفات', 'حسب البند وحسب التاريخ', Symbols.payments),
  customerDebts('customer-debts', 'ديون العملاء', 'أرصدة العملاء المستحقة', Symbols.person_alert),
  supplierPayables('supplier-payables', 'مستحقات الموردين', 'المبالغ المستحقة للموردين', Symbols.local_shipping),
  cashboxes('cashboxes', 'تقرير الخزائن', 'رصيد أول وآخر المدة والوارد والمنصرف والتحويلات', Symbols.account_balance_wallet),
  services('services', 'تقرير الخدمات', 'عدد مرات البيع والإيراد والتكلفة والربح والهامش', Symbols.home_repair_service),
  products('products', 'تقرير المنتجات والمخزون', 'الكميات وقيمة المخزون بالتكلفة', Symbols.inventory_2),
  journal('journal', 'سجل الحركات المالية', 'كل القيود المالية بالترتيب الزمني', Symbols.list_alt);

  const ReportType(this.slug, this.title, this.description, this.icon);
  final String slug;
  final String title;
  final String description;
  final IconData icon;

  /// Snapshot reports show current balances and ignore the period.
  bool get usesPeriod => this != customerDebts && this != supplierPayables && this != products;

  /// Reports exposing cost/profit need the view_cost permission.
  bool get needsCost => this == profit || this == services || this == products || this == sales;

  static ReportType parse(String slug) =>
      ReportType.values.firstWhere((e) => e.slug == slug, orElse: () => profit);
}
