import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/accounting/posting.dart';
import '../../../core/permissions/permissions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/module_colors.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/money_text.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/period_selector.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../core/widgets/states.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/app_user.dart';
import '../../cashboxes/application/cashbox_providers.dart';
import '../../notifications/notifications.dart';
import '../../settings/application/settings_providers.dart';
import '../application/dashboard_providers.dart';
import '../domain/stats.dart';
import 'activity_list.dart';
import 'charts.dart';

/// "How is my business doing?" — the first screen after login.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider)!;
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'صباح الخير' : 'مساء الخير';
    final canSee = user.can(Permission.viewDashboard);

    return PageScaffold(
      title: canSee ? 'لوحة التحكم' : 'الرئيسية',
      subtitle: canSee ? 'نظرة شاملة على أداء نشاطك' : null,
      actions: [if (context.isMobile) const NotificationBell()],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _WelcomeBanner(greeting: greeting, name: user.name, role: user.roleName),
          const SizedBox(height: 16),
          _QuickActions(user: user),
          if (canSee) ...[
            const SizedBox(height: 16),
            const _KpiGrid(),
            const SizedBox(height: 20),
            const _PeriodSection(),
            const SizedBox(height: 16),
            const _BottomSection(),
          ] else ...[
            const SizedBox(height: 24),
            const Card(
              child: EmptyState(
                icon: Symbols.lock,
                title: 'لا تملك صلاحية عرض المؤشرات المالية',
                message: 'استخدم الإجراءات السريعة أعلاه لبدء العمل.',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final actions = [
      if (user.can(Permission.createSales)) ('فاتورة بيع', Symbols.receipt_long, '/sales/new', ModuleColors.sales),
      if (user.can(Permission.createPurchases)) ('فاتورة شراء', Symbols.shopping_cart, '/purchases/new', ModuleColors.purchases),
      if (user.can(Permission.createPayment)) ('تحصيل من عميل', Symbols.call_received, '/receipts/new', ModuleColors.receipts),
      if (user.can(Permission.createSupplierPayment)) ('دفع لمورد', Symbols.call_made, '/supplier-payments/new', ModuleColors.supplierPayments),
      if (user.can(Permission.createExpense)) ('إضافة مصروف', Symbols.payments, '/expenses/new', ModuleColors.expenses),
      if (user.can(Permission.createTransfer)) ('تحويل بين الخزائن', Symbols.swap_horiz, '/transfers/new', ModuleColors.transfers),
      if (user.can(Permission.manageCatalog)) ('إضافة خدمة', Symbols.home_repair_service, '/services', ModuleColors.services),
    ];
    if (actions.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final a in actions)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 10),
              child: Material(
                color: ModuleColors.soft(a.$4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: a.$4.withValues(alpha: 0.35)),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => context.push(a.$3),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
                    child: Row(
                      children: [
                        ModuleIcon(icon: a.$2, color: a.$4, size: 36, solid: true),
                        const SizedBox(width: 10),
                        Text(a.$1, style: TextStyle(fontWeight: FontWeight.w700, color: a.$4)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _KpiGrid extends ConsumerWidget {
  const _KpiGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(monthStatsProvider);
    final cash = ref.watch(totalCashProvider);
    final cashLoading = ref.watch(cashboxesProvider).isLoading;
    final receivables = ref.watch(receivablesProvider);
    final payables = ref.watch(payablesProvider);
    final period = ref.watch(dashboardPeriodProvider);
    final periodStats = ref.watch(dailyStatsProvider(period.range));
    final canCost = ref.watch(canProvider(Permission.viewCost));
    final today = stats.value?.today;
    final month = stats.value?.month;
    final periodExpenses = periodStats.whenData((s) => StatsMath.total(s).expenses);

    return ResponsiveGrid(
      minItemWidth: 230,
      children: [
        StatCard(
          label: 'رصيد الخزائن',
          icon: Symbols.account_balance_wallet,
          amount: cash,
          loading: cashLoading,
          tone: cash < 0 ? Tone.danger : Tone.primary,
          color: cash < 0 ? null : ModuleColors.cashboxes,
          onTap: () => context.go('/cashboxes'),
        ),
        StatCard(
          label: 'مبيعات اليوم',
          icon: Symbols.today,
          amount: today?.sales,
          loading: stats.isLoading,
          tone: Tone.info,
          color: ModuleColors.sales,
          hint: today == null ? null : '${today.salesCount} فاتورة',
          onTap: () => context.go('/sales'),
        ),
        StatCard(
          label: 'مبيعات الشهر',
          icon: Symbols.calendar_month,
          amount: month?.sales,
          loading: stats.isLoading,
          tone: Tone.info,
          color: ModuleColors.sales,
          hint: month == null ? null : '${month.salesCount} فاتورة',
        ),
        if (canCost) ...[
          StatCard(
            label: 'أرباح اليوم',
            icon: Symbols.trending_up,
            amount: today?.netProfit,
            loading: stats.isLoading,
            tone: (today?.netProfit ?? 0) < 0 ? Tone.danger : Tone.success,
            hint: 'بعد خصم التكلفة والمصروفات',
          ),
          StatCard(
            label: 'أرباح الشهر',
            icon: Symbols.monitoring,
            amount: month?.netProfit,
            loading: stats.isLoading,
            tone: (month?.netProfit ?? 0) < 0 ? Tone.danger : Tone.success,
            hint: month == null ? null : 'إجمالي الربح: ${ref.watch(moneyFormatterProvider)(month.grossProfit)}',
            onTap: () => context.push('/reports/profit'),
          ),
        ],
        StatCard(
          label: 'المصروفات (${period.label})',
          icon: Symbols.payments,
          color: ModuleColors.expenses,
          amount: periodExpenses.value,
          loading: periodExpenses.isLoading,
          tone: Tone.danger,
          onTap: () => context.go('/expenses'),
        ),
        StatCard(
          label: 'ديون العملاء',
          icon: Symbols.person_alert,
          color: ModuleColors.customers,
          amount: receivables.value?.total,
          loading: receivables.isLoading,
          tone: Tone.warning,
          hint: receivables.value == null ? null : '${receivables.value!.count} عميل',
          onTap: () => context.push('/reports/customer-debts'),
        ),
        StatCard(
          label: 'مستحقات الموردين',
          icon: Symbols.local_shipping,
          color: ModuleColors.suppliers,
          amount: payables.value?.total,
          loading: payables.isLoading,
          tone: Tone.warning,
          hint: payables.value == null ? null : '${payables.value!.count} مورد',
          onTap: () => context.push('/reports/supplier-payables'),
        ),
      ],
    );
  }
}

class _PeriodSection extends ConsumerWidget {
  const _PeriodSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(dashboardPeriodProvider);
    final stats = ref.watch(dailyStatsProvider(period.range));
    final canCost = ref.watch(canProvider(Permission.viewCost));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('الأداء خلال الفترة', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(width: 16),
            Expanded(
              child: PeriodSelector(
                value: period,
                onChanged: ref.read(dashboardPeriodProvider.notifier).set,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        stats.when(
          loading: () => const SizedBox(height: 280, child: Center(child: CircularProgressIndicator())),
          error: (e, s) => ErrorState(error: e, stackTrace: s),
          data: (list) {
            final points = StatsMath.series(list, period.range);
            final total = StatsMath.total(list);
            final sales = AppCard(
              title: canCost ? 'المبيعات والأرباح' : 'المبيعات',
              subtitle: _summaryLine(ref, total, canCost),
              trailing: ChartLegend([
                const ChartSeries('المبيعات', AppColors.primary, _sales),
                if (canCost) const ChartSeries('صافي الربح', AppColors.success, _profit),
              ]),
              child: TrendLineChart(points: points, series: [
                const ChartSeries('المبيعات', AppColors.primary, _sales),
                if (canCost) const ChartSeries('صافي الربح', AppColors.success, _profit),
              ]),
            );
            final expenses = AppCard(
              title: 'المصروفات',
              subtitle: 'الإجمالي: ${ref.watch(moneyFormatterProvider)(total.expenses)}',
              child: TrendBarChart(
                points: points,
                series: const [ChartSeries('المصروفات', AppColors.danger, _expenses)],
                height: 200,
              ),
            );
            final cashFlow = AppCard(
              title: 'التدفق النقدي',
              subtitle: 'صافي: ${ref.watch(moneyFormatterProvider)(total.cashIn - total.cashOut)}',
              trailing: const ChartLegend([
                ChartSeries('وارد', AppColors.success, _cashIn),
                ChartSeries('منصرف', AppColors.danger, _cashOut),
              ]),
              child: TrendBarChart(
                points: points,
                series: const [
                  ChartSeries('وارد', AppColors.success, _cashIn),
                  ChartSeries('منصرف', AppColors.danger, _cashOut),
                ],
                height: 200,
              ),
            );
            if (context.isDesktop) {
              return Column(
                children: [
                  sales,
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: expenses),
                      const SizedBox(width: 16),
                      Expanded(child: cashFlow),
                    ],
                  ),
                ],
              );
            }
            return Column(children: [sales, const SizedBox(height: 12), expenses, const SizedBox(height: 12), cashFlow]);
          },
        ),
      ],
    );
  }

  static String _summaryLine(WidgetRef ref, PostingMetrics t, bool canCost) {
    final f = ref.watch(moneyFormatterProvider);
    return canCost
        ? 'مبيعات ${f(t.sales)} • ربح إجمالي ${f(t.grossProfit)} • صافي ${f(t.netProfit)}'
        : 'مبيعات ${f(t.sales)} • ${t.salesCount} فاتورة';
  }
}

int _sales(PostingMetrics m) => m.sales;
int _profit(PostingMetrics m) => m.netProfit;
int _expenses(PostingMetrics m) => m.expenses;
int _cashIn(PostingMetrics m) => m.cashIn;
int _cashOut(PostingMetrics m) => m.cashOut;

class _BottomSection extends ConsumerWidget {
  const _BottomSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = AppCard(
      title: 'آخر العمليات',
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
      trailing: Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: TextButton(onPressed: () => context.push('/reports/journal'), child: const Text('عرض الكل')),
      ),
      child: AsyncView(
        value: ref.watch(recentActivityProvider),
        loading: const LoadingState(rows: 5, card: false),
        data: (list) => list.isEmpty
            ? const EmptyState(
                icon: Symbols.history,
                title: 'لا توجد عمليات بعد',
                message: 'ستظهر هنا المبيعات والمشتريات والتحصيلات والمصروفات فور تسجيلها.',
                compact: true,
              )
            : Column(children: [for (final a in list) ActivityTile(activity: a, dense: true)]),
      ),
    );
    final alerts = _Alerts();
    if (context.isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Expanded(flex: 3, child: activity), const SizedBox(width: 16), Expanded(flex: 2, child: alerts)],
      );
    }
    return Column(children: [alerts, const SizedBox(height: 12), activity]);
  }
}

class _Alerts extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(companySettingsProvider);
    final lowBoxes = ref
        .watch(activeCashboxesProvider)
        .where((b) => b.balance < 0 || (settings.lowCashThreshold > 0 && b.balance < settings.lowCashThreshold))
        .toList();
    final debtors = ref.watch(topDebtorsProvider).value ?? const [];
    final payables = ref.watch(topPayablesProvider).value ?? const [];
    final t = Theme.of(context).textTheme;

    Widget section(String title, IconData icon, Tone tone, List<Widget> rows) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Icon(icon, size: 18, color: tone.color),
                const SizedBox(width: 6),
                Text(title, style: t.titleSmall),
              ]),
              const SizedBox(height: 6),
              ...rows,
            ],
          ),
        );

    Widget row(String name, int amount, Tone tone, String route) => InkWell(
          onTap: () => context.push(route),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Expanded(child: Text(name, overflow: TextOverflow.ellipsis)),
              MoneyText(amount, tone: tone),
            ]),
          ),
        );

    final sections = [
      if (lowBoxes.isNotEmpty)
        section('خزائن برصيد منخفض', Symbols.warning, Tone.danger, [
          for (final b in lowBoxes) row(b.name, b.balance, Tone.danger, '/cashboxes/${b.id}'),
        ]),
      if (debtors.isNotEmpty)
        section('أعلى ديون العملاء', Symbols.person_alert, Tone.warning, [
          for (final d in debtors) row(d.name, d.balance, Tone.danger, '/customers/${d.id}'),
        ]),
      if (payables.isNotEmpty)
        section('أعلى مستحقات الموردين', Symbols.local_shipping, Tone.warning, [
          for (final d in payables) row(d.name, d.balance, Tone.warning, '/suppliers/${d.id}'),
        ]),
    ];

    return AppCard(
      title: 'تنبيهات ومتابعة',
      child: sections.isEmpty
          ? const EmptyState(
              icon: Symbols.task_alt,
              title: 'لا توجد تنبيهات',
              message: 'لا ديون مستحقة ولا خزائن منخفضة الرصيد.',
              compact: true,
            )
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: sections),
    );
  }
}

/// Greeting banner in the Alfardos brand colors (teal → indigo).
class _WelcomeBanner extends ConsumerWidget {
  const _WelcomeBanner({required this.greeting, required this.name, required this.role});

  final String greeting;
  final String name;
  final String role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final company = ref.watch(companySettingsProvider).companyName;
    final now = DateTime.now();
    const days = ['الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
    final date = '${days[now.weekday - 1]} ${now.day} ${Dates.monthName(now.month)} ${now.year}';
    final t = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsets.all(context.isMobile ? 16 : 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: AlignmentDirectional.centerStart,
          end: AlignmentDirectional.centerEnd,
          colors: [ModuleColors.brandTeal, ModuleColors.dashboard],
        ),
        boxShadow: [
          BoxShadow(color: ModuleColors.brandTeal.withValues(alpha: 0.25), blurRadius: 18, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Image.asset('assets/branding/logo_mark.png', width: context.isMobile ? 44 : 56),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$greeting، $name 👋',
                    style: t.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('$company • $role',
                    style: t.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.9))),
              ],
            ),
          ),
          if (!context.isMobile)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ModuleColors.brandGold.withValues(alpha: 0.8)),
              ),
              child: Row(
                children: [
                  const Icon(Symbols.calendar_today, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(date, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
