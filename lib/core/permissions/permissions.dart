/// Granular permissions. The string ids are stored on user documents and
/// checked by Firestore security rules — keep them in sync with
/// `firestore.rules`.
enum Permission {
  admin('admin', 'مدير النظام (كل الصلاحيات)', PermissionGroup.system),

  viewDashboard('view_dashboard', 'عرض لوحة التحكم', PermissionGroup.general),
  viewReports('view_reports', 'عرض التقارير', PermissionGroup.general),

  viewSales('view_sales', 'عرض المبيعات', PermissionGroup.sales),
  createSales('create_sales', 'إنشاء فواتير البيع', PermissionGroup.sales),
  cancelSales('cancel_sales', 'إلغاء فواتير البيع', PermissionGroup.sales),

  viewCustomers('view_customers', 'عرض العملاء', PermissionGroup.customers),
  manageCustomers('manage_customers', 'إضافة وتعديل العملاء', PermissionGroup.customers),
  createPayment('create_payment', 'تحصيل من العملاء', PermissionGroup.customers),

  viewPurchases('view_purchases', 'عرض المشتريات', PermissionGroup.purchases),
  createPurchases('create_purchases', 'إنشاء فواتير الشراء', PermissionGroup.purchases),
  cancelPurchases('cancel_purchases', 'إلغاء فواتير الشراء', PermissionGroup.purchases),

  viewSuppliers('view_suppliers', 'عرض الموردين', PermissionGroup.suppliers),
  manageSuppliers('manage_suppliers', 'إضافة وتعديل الموردين', PermissionGroup.suppliers),
  createSupplierPayment('create_supplier_payment', 'الدفع للموردين', PermissionGroup.suppliers),

  viewCashboxes('view_cashboxes', 'عرض الخزائن', PermissionGroup.cash),
  manageCashboxes('manage_cashboxes', 'إدارة الخزائن', PermissionGroup.cash),
  createTransfer('create_transfer', 'التحويل بين الخزائن', PermissionGroup.cash),

  viewExpenses('view_expenses', 'عرض المصروفات', PermissionGroup.expenses),
  createExpense('create_expense', 'تسجيل المصروفات', PermissionGroup.expenses),
  manageExpenseCategories('manage_expense_categories', 'إدارة بنود المصروفات', PermissionGroup.expenses),

  cancelPayments('cancel_payments', 'إلغاء السندات والمصروفات والتحويلات', PermissionGroup.cash),

  viewCatalog('view_catalog', 'عرض المنتجات والخدمات', PermissionGroup.catalog),
  manageCatalog('manage_catalog', 'إدارة المنتجات والخدمات والأسعار', PermissionGroup.catalog),
  viewCost('view_cost', 'عرض التكلفة والأرباح', PermissionGroup.catalog),

  manageUsers('manage_users', 'إدارة المستخدمين والصلاحيات', PermissionGroup.system),
  manageSettings('manage_settings', 'إدارة الإعدادات', PermissionGroup.system),
  viewAudit('view_audit', 'عرض سجل التدقيق', PermissionGroup.system);

  const Permission(this.id, this.label, this.group);
  final String id;
  final String label;
  final PermissionGroup group;

  static Permission? tryParse(String id) {
    for (final p in values) {
      if (p.id == id) return p;
    }
    return null;
  }
}

enum PermissionGroup {
  general('عام'),
  sales('المبيعات'),
  customers('العملاء'),
  purchases('المشتريات'),
  suppliers('الموردون'),
  cash('الخزائن والسندات'),
  expenses('المصروفات'),
  catalog('المنتجات والخدمات'),
  system('النظام');

  const PermissionGroup(this.label);
  final String label;
}

/// Built-in roles created on first setup. Admins can edit them or add custom
/// roles from the Users & Permissions screen.
abstract final class DefaultRoles {
  static const admin = (id: 'admin', name: 'مدير النظام', permissions: [Permission.admin]);

  static const accountant = (
    id: 'accountant',
    name: 'محاسب',
    permissions: [
      Permission.viewDashboard,
      Permission.viewReports,
      Permission.viewSales,
      Permission.createSales,
      Permission.cancelSales,
      Permission.viewCustomers,
      Permission.manageCustomers,
      Permission.createPayment,
      Permission.viewPurchases,
      Permission.createPurchases,
      Permission.cancelPurchases,
      Permission.viewSuppliers,
      Permission.manageSuppliers,
      Permission.createSupplierPayment,
      Permission.viewCashboxes,
      Permission.createTransfer,
      Permission.viewExpenses,
      Permission.createExpense,
      Permission.manageExpenseCategories,
      Permission.cancelPayments,
      Permission.viewCatalog,
      Permission.manageCatalog,
      Permission.viewCost,
    ],
  );

  static const cashier = (
    id: 'cashier',
    name: 'أمين صندوق',
    permissions: [
      Permission.viewDashboard,
      Permission.viewSales,
      Permission.createSales,
      Permission.viewCustomers,
      Permission.createPayment,
      Permission.viewSuppliers,
      Permission.createSupplierPayment,
      Permission.viewCashboxes,
      Permission.createTransfer,
      Permission.viewExpenses,
      Permission.createExpense,
      Permission.viewCatalog,
    ],
  );

  static const sales = (
    id: 'sales',
    name: 'مندوب مبيعات',
    permissions: [
      Permission.viewSales,
      Permission.createSales,
      Permission.viewCustomers,
      Permission.manageCustomers,
      Permission.createPayment,
      Permission.viewCatalog,
    ],
  );

  static const all = [admin, accountant, cashier, sales];
}
