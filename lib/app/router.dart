import 'dart:io' show Platform;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/permissions/permissions.dart';
import '../features/audit/presentation/audit_log_screen.dart';
import '../features/auth/application/auth_providers.dart';
import '../features/auth/domain/app_user.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/profile_screen.dart';
import '../features/auth/presentation/setup_screen.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/cashboxes/presentation/cashbox_details_screen.dart';
import '../features/cashboxes/presentation/cashbox_list_screen.dart';
import '../features/cashboxes/presentation/transfer_form_screen.dart';
import '../features/cashboxes/presentation/transfers_list_screen.dart';
import '../features/catalog/presentation/products_screen.dart';
import '../features/catalog/presentation/services_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/expenses/presentation/expense_categories_screen.dart';
import '../features/expenses/presentation/expense_form_screen.dart';
import '../features/expenses/presentation/expense_list_screen.dart';
import '../features/invoices/domain/invoice.dart';
import '../features/invoices/presentation/invoice_details_screen.dart';
import '../features/invoices/presentation/invoice_form_screen.dart';
import '../features/invoices/presentation/invoice_list_screen.dart';
import '../features/notifications/notifications.dart';
import '../features/parties/domain/party.dart';
import '../features/parties/presentation/party_details_screen.dart';
import '../features/parties/presentation/party_list_screen.dart';
import '../features/parties/presentation/payment_form_screen.dart';
import '../features/parties/presentation/payments_list_screen.dart';
import '../features/reports/domain/report_type.dart';
import '../features/reports/presentation/report_screen.dart';
import '../features/reports/presentation/reports_hub_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/users/presentation/users_screen.dart';
import 'shell/app_shell.dart';
import 'shell/more_screen.dart';

/// Route prefix → permissions (any of). Checked on every navigation; the
/// same permissions are enforced server-side by Firestore security rules.
const _guards = <String, List<Permission>>{
  '/sales/new': [Permission.createSales],
  '/sales': [Permission.viewSales],
  '/purchases/new': [Permission.createPurchases],
  '/purchases': [Permission.viewPurchases],
  '/customers': [Permission.viewCustomers],
  '/suppliers': [Permission.viewSuppliers],
  '/receipts/new': [Permission.createPayment],
  '/receipts': [Permission.viewCustomers],
  '/supplier-payments/new': [Permission.createSupplierPayment],
  '/supplier-payments': [Permission.viewSuppliers],
  '/cashboxes': [Permission.viewCashboxes],
  '/transfers/new': [Permission.createTransfer],
  '/transfers': [Permission.viewCashboxes],
  '/expenses/new': [Permission.createExpense],
  '/expenses/categories': [Permission.manageExpenseCategories],
  '/expenses': [Permission.viewExpenses],
  '/products': [Permission.viewCatalog],
  '/services': [Permission.viewCatalog],
  '/reports': [Permission.viewReports],
  '/users': [Permission.manageUsers],
  '/settings': [Permission.manageSettings],
  '/audit': [Permission.viewAudit],
};

bool canVisit(AppUser user, String location) {
  for (final e in _guards.entries) {
    if (location == e.key || location.startsWith('${e.key}/') || location.startsWith('${e.key}?')) {
      return user.canAny(e.value);
    }
  }
  return true;
}

const _publicRoutes = {'/login', '/forgot-password', '/setup'};

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authStateProvider, (_, _) => refresh.value++);
  ref.listen(userProfileProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    observers: [
      // Screen-view analytics (Firebase Analytics is available on Android).
      if (!kIsWeb && Platform.isAndroid) FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
    ],
    debugLogDiagnostics: kDebugMode,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final profile = ref.read(userProfileProvider);
      final loc = state.matchedLocation;

      if (auth.isLoading) return loc == '/splash' ? null : '/splash';
      final signedIn = auth.value != null;
      if (!signedIn) {
        return _publicRoutes.contains(loc) ? null : '/login';
      }
      if (profile.isLoading && !profile.hasValue) return loc == '/splash' ? null : '/splash';
      final user = profile.value;
      if (user == null || !user.active) {
        // Signed in to Firebase but not an active member of this business.
        return loc == '/login' || loc == '/setup' ? null : '/login';
      }
      if (_publicRoutes.contains(loc) || loc == '/splash') return '/';
      if (!canVisit(user, state.uri.toString())) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/forgot-password', builder: (_, _) => const ForgotPasswordScreen()),
      GoRoute(path: '/setup', builder: (_, _) => const SetupScreen()),
      ShellRoute(
        // The shell reads the live location from the router itself so pushed
        // pages (e.g. /sales/new over /products) highlight correctly.
        builder: (context, state, child) {
          final router = GoRouter.of(context);
          return ListenableBuilder(
            listenable: router.routerDelegate,
            builder: (context, _) => AppShell(
              location: router.routerDelegate.currentConfiguration.uri.path,
              child: child,
            ),
          );
        },
        routes: [
          GoRoute(path: '/', builder: (_, _) => const DashboardScreen()),
          GoRoute(path: '/more', builder: (_, _) => const MoreScreen()),
          ..._invoiceRoutes(InvoiceKind.sale),
          ..._invoiceRoutes(InvoiceKind.purchase),
          ..._partyRoutes(PartyKind.customer, paymentsPath: '/receipts'),
          ..._partyRoutes(PartyKind.supplier, paymentsPath: '/supplier-payments'),
          GoRoute(
            path: '/cashboxes',
            builder: (_, _) => const CashboxListScreen(),
            routes: [
              GoRoute(path: ':id', builder: (_, s) => CashboxDetailsScreen(id: s.pathParameters['id']!)),
            ],
          ),
          GoRoute(
            path: '/transfers',
            builder: (_, _) => const TransfersListScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (_, s) => TransferFormScreen(fromId: s.uri.queryParameters['from']),
              ),
            ],
          ),
          GoRoute(
            path: '/expenses',
            builder: (_, _) => const ExpenseListScreen(),
            routes: [
              GoRoute(path: 'new', builder: (_, _) => const ExpenseFormScreen()),
              GoRoute(path: 'categories', builder: (_, _) => const ExpenseCategoriesScreen()),
            ],
          ),
          GoRoute(
            path: '/products',
            builder: (_, s) => ProductsScreen(initialQuery: s.uri.queryParameters['q'] ?? ''),
          ),
          GoRoute(path: '/services', builder: (_, _) => const ServicesScreen()),
          GoRoute(
            path: '/reports',
            builder: (_, _) => const ReportsHubScreen(),
            routes: [
              GoRoute(
                path: ':type',
                builder: (_, s) => ReportScreen(type: ReportType.parse(s.pathParameters['type']!)),
              ),
            ],
          ),
          GoRoute(path: '/users', builder: (_, _) => const UsersScreen()),
          GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
          GoRoute(path: '/audit', builder: (_, _) => const AuditLogScreen()),
          GoRoute(path: '/notifications', builder: (_, _) => const NotificationsScreen()),
          GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
        ],
      ),
    ],
    errorBuilder: (_, _) => const Scaffold(body: Center(child: Text('الصفحة غير موجودة'))),
  );
  ref.onDispose(router.dispose);
  return router;
});

List<RouteBase> _invoiceRoutes(InvoiceKind kind) => [
      GoRoute(
        path: kind.route,
        builder: (_, _) => InvoiceListScreen(kind: kind),
        routes: [
          GoRoute(
            path: 'new',
            builder: (_, s) => InvoiceFormScreen(
              kind: kind,
              partyId: s.uri.queryParameters['party'],
              copyFromId: s.uri.queryParameters['copy'],
            ),
          ),
          GoRoute(
            path: ':id',
            builder: (_, s) => InvoiceDetailsScreen(kind: kind, id: s.pathParameters['id']!),
          ),
        ],
      ),
    ];

List<RouteBase> _partyRoutes(PartyKind kind, {required String paymentsPath}) => [
      GoRoute(
        path: kind.route,
        builder: (_, _) => PartyListScreen(kind: kind),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, s) => PartyDetailsScreen(kind: kind, id: s.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: paymentsPath,
        builder: (_, _) => PaymentsListScreen(kind: kind),
        routes: [
          GoRoute(
            path: 'new',
            builder: (_, s) => PaymentFormScreen(kind: kind, partyId: s.uri.queryParameters['party']),
          ),
        ],
      ),
    ];
