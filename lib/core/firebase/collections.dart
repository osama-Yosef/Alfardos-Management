/// Firestore collection names. The whole database is single-tenant: one
/// Firebase project = one business.
abstract final class Col {
  static const users = 'users';
  static const roles = 'roles';
  static const meta = 'meta';
  static const settings = 'settings';
  static const counters = 'counters';

  static const customers = 'customers';
  static const suppliers = 'suppliers';
  static const products = 'products';
  static const services = 'services';
  static const cashboxes = 'cashboxes';
  static const expenseCategories = 'expense_categories';

  static const sales = 'sales';
  static const saleItems = 'sale_items';
  static const purchases = 'purchases';
  static const purchaseItems = 'purchase_items';
  static const customerPayments = 'customer_payments';
  static const supplierPayments = 'supplier_payments';
  static const expenses = 'expenses';
  static const transfers = 'transfers';

  static const financialTransactions = 'financial_transactions';
  static const cashTransactions = 'cash_transactions';
  static const customerTransactions = 'customer_transactions';
  static const supplierTransactions = 'supplier_transactions';
  static const dailyStats = 'daily_stats';

  static const auditLogs = 'audit_logs';
  static const notifications = 'notifications';
}

/// Document ids inside [Col.settings] / [Col.meta].
abstract final class DocIds {
  static const companySettings = 'company';
  static const bootstrap = 'bootstrap';
}

/// Sequential document numbering counters.
enum Counter {
  sales('sales'),
  purchases('purchases'),
  customerPayments('customer_payments'),
  supplierPayments('supplier_payments'),
  expenses('expenses'),
  transfers('transfers');

  const Counter(this.id);
  final String id;
}
