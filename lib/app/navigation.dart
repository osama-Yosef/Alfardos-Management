import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/permissions/permissions.dart';
import '../core/theme/module_colors.dart';
import '../features/auth/domain/app_user.dart';

class NavItem {
  const NavItem(this.label, this.icon, this.path, this.color, {this.permissions = const []});

  final String label;
  final IconData icon;
  final String path;

  /// Section color (see [ModuleColors]).
  final Color color;

  /// Visible when the user has any of these (empty = everyone).
  final List<Permission> permissions;

  bool visibleFor(AppUser user) => permissions.isEmpty || user.canAny(permissions);
}

class NavGroup {
  const NavGroup(this.label, this.items);
  final String? label;
  final List<NavItem> items;
}

/// Navigation ordered by daily-work importance.
abstract final class AppNav {
  static const dashboard = NavItem('لوحة التحكم', Symbols.space_dashboard, '/', ModuleColors.dashboard);
  static const sales = NavItem('المبيعات', Symbols.receipt_long, '/sales', ModuleColors.sales,
      permissions: [Permission.viewSales]);
  static const customers = NavItem('العملاء', Symbols.groups, '/customers', ModuleColors.customers,
      permissions: [Permission.viewCustomers]);
  static const receipts = NavItem('التحصيلات', Symbols.call_received, '/receipts', ModuleColors.receipts,
      permissions: [Permission.viewCustomers]);
  static const purchases = NavItem('المشتريات', Symbols.shopping_cart, '/purchases', ModuleColors.purchases,
      permissions: [Permission.viewPurchases]);
  static const suppliers = NavItem('الموردون', Symbols.local_shipping, '/suppliers', ModuleColors.suppliers,
      permissions: [Permission.viewSuppliers]);
  static const supplierPayments = NavItem('مدفوعات الموردين', Symbols.call_made, '/supplier-payments',
      ModuleColors.supplierPayments, permissions: [Permission.viewSuppliers]);
  static const cashboxes = NavItem('الخزائن', Symbols.account_balance_wallet, '/cashboxes', ModuleColors.cashboxes,
      permissions: [Permission.viewCashboxes]);
  static const transfers = NavItem('التحويلات', Symbols.swap_horiz, '/transfers', ModuleColors.transfers,
      permissions: [Permission.viewCashboxes]);
  static const expenses = NavItem('المصروفات', Symbols.payments, '/expenses', ModuleColors.expenses,
      permissions: [Permission.viewExpenses]);
  static const services = NavItem('الخدمات', Symbols.home_repair_service, '/services', ModuleColors.services,
      permissions: [Permission.viewCatalog]);
  static const products = NavItem('المنتجات والمخزون', Symbols.inventory_2, '/products', ModuleColors.products,
      permissions: [Permission.viewCatalog]);
  static const reports = NavItem('التقارير', Symbols.monitoring, '/reports', ModuleColors.reports,
      permissions: [Permission.viewReports]);
  static const users = NavItem('المستخدمون والصلاحيات', Symbols.manage_accounts, '/users', ModuleColors.users,
      permissions: [Permission.manageUsers]);
  static const settings = NavItem('الإعدادات', Symbols.settings, '/settings', ModuleColors.settings,
      permissions: [Permission.manageSettings]);
  static const audit = NavItem('سجل التدقيق', Symbols.history, '/audit', ModuleColors.audit,
      permissions: [Permission.viewAudit]);

  // Pages outside the sidebar that still get a colored header.
  static const _extra = [
    NavItem('الإشعارات', Symbols.notifications, '/notifications', ModuleColors.dashboard),
    NavItem('الملف الشخصي', Symbols.person, '/profile', ModuleColors.users),
    NavItem('المزيد', Symbols.menu, '/more', ModuleColors.dashboard),
  ];

  static const groups = [
    NavGroup(null, [dashboard]),
    NavGroup('المبيعات', [sales, customers, receipts]),
    NavGroup('المشتريات', [purchases, suppliers, supplierPayments]),
    NavGroup('المالية', [cashboxes, transfers, expenses]),
    NavGroup('الأصناف', [services, products]),
    NavGroup('التحليل', [reports]),
    NavGroup('النظام', [users, settings, audit]),
  ];

  /// Phone bottom bar: the four most used destinations + "more".
  static const mobilePrimary = [dashboard, sales, customers, cashboxes];

  static List<NavItem> get all => [for (final g in groups) ...g.items];

  /// Most specific nav item matching a location (for highlighting).
  static NavItem? match(String location, {bool includeExtra = false}) {
    NavItem? best;
    for (final item in [...all, if (includeExtra) ..._extra]) {
      final hit = item.path == '/'
          ? location == '/'
          : location == item.path || location.startsWith('${item.path}/');
      if (hit && (best == null || item.path.length > best.path.length)) best = item;
    }
    return best;
  }
}
