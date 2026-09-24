import '../../../core/accounting/invoice_calculator.dart';
import '../../../core/accounting/posting.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/dates.dart';
import '../../cashboxes/domain/cashbox.dart';
import '../../catalog/domain/catalog_item.dart';
import '../../dashboard/domain/stats.dart';
import '../../expenses/domain/expense.dart';
import '../../invoices/domain/invoice.dart';
import '../../parties/domain/party.dart';
import 'report_data.dart';

/// A cash movement as needed by the cashbox report.
class CashMove {
  const CashMove({required this.cashboxId, required this.amount, required this.date, required this.isTransfer});
  final String cashboxId;
  final int amount;
  final DateTime date;
  final bool isTransfer;
}

/// A sold line (or its reversal) as needed by the services report.
class SoldItem {
  const SoldItem({
    required this.itemId,
    required this.name,
    required this.kind,
    required this.quantity,
    required this.net,
    required this.cost,
  });
  final String itemId;
  final String name;
  final LineKind kind;
  final double quantity;
  final int net;
  final int cost;
}

/// Pure report calculations. Every figure is derived from the underlying
/// records passed in — nothing is hard-coded or read from cached totals.
abstract final class ReportBuilders {
  static const _money = CellType.money;

  /// Net profit = revenue − COGS − service cost − operating expenses.
  /// Sourced from the ledger's daily statistics (reversals included on the
  /// date they were posted).
  static ReportData profit(List<DailyStat> stats, DateRange range) {
    final total = StatsMath.total(stats, range);
    final points = StatsMath.series(stats, range).where((p) => p.metrics.txCountLike).toList();
    return ReportData(
      kpis: [
        ReportKpi('الإيرادات (صافي المبيعات)', total.sales, tone: Tone.info),
        ReportKpi('تكلفة البضاعة المباعة', total.productCost, tone: Tone.warning),
        ReportKpi('تكلفة الخدمات', total.serviceCost, tone: Tone.warning),
        ReportKpi('مجمل الربح', total.grossProfit, tone: total.grossProfit < 0 ? Tone.danger : Tone.success),
        ReportKpi('المصروفات التشغيلية', total.expenses, tone: Tone.danger),
        ReportKpi('صافي الربح', total.netProfit, tone: total.netProfit < 0 ? Tone.danger : Tone.success),
      ],
      columns: const [
        ReportColumn('الفترة'),
        ReportColumn('المبيعات', type: _money),
        ReportColumn('تكلفة البضاعة', type: _money),
        ReportColumn('تكلفة الخدمات', type: _money),
        ReportColumn('مجمل الربح', type: _money),
        ReportColumn('المصروفات', type: _money),
        ReportColumn('صافي الربح', type: _money),
      ],
      rows: [
        for (final p in points)
          [
            p.label,
            p.metrics.sales,
            p.metrics.productCost,
            p.metrics.serviceCost,
            p.metrics.grossProfit,
            p.metrics.expenses,
            p.metrics.netProfit,
          ],
      ],
      footer: [
        'الإجمالي',
        total.sales,
        total.productCost,
        total.serviceCost,
        total.grossProfit,
        total.expenses,
        total.netProfit,
      ],
      note: 'المشتريات لا تُحتسب مصروفاً: تدخل المخزون وتُحمَّل على الأرباح عند بيعها بتكلفتها الفعلية.',
    );
  }

  static ReportData sales(List<Invoice> invoices, {required bool showCost}) {
    final active = invoices.where((i) => !i.cancelled).toList();
    int sum(int Function(Invoice) f, [Iterable<Invoice>? src]) => (src ?? active).fold<int>(0, (s, i) => s + f(i));
    final cash = active.where((i) => i.paymentStatus == PaymentStatus.paid);
    final credit = active.where((i) => i.paymentStatus != PaymentStatus.paid);
    return ReportData(
      kpis: [
        ReportKpi('إجمالي المبيعات', sum((i) => i.total), tone: Tone.info),
        ReportKpi('مبيعات نقدية', sum((i) => i.total, cash), tone: Tone.success),
        ReportKpi('مبيعات آجلة / جزئية', sum((i) => i.total, credit), tone: Tone.warning),
        ReportKpi('المدفوع', sum((i) => i.paid), tone: Tone.success),
        ReportKpi('المتبقي', sum((i) => i.remaining), tone: Tone.danger),
        if (showCost) ReportKpi('التكلفة', sum((i) => i.totalCost), tone: Tone.warning),
        if (showCost) ReportKpi('مجمل الربح', sum((i) => i.grossProfit), tone: Tone.success),
        ReportKpi('عدد الفواتير', active.length, tone: Tone.neutral, isMoney: false),
      ],
      columns: [
        const ReportColumn('رقم الفاتورة'),
        const ReportColumn('التاريخ', type: CellType.date),
        const ReportColumn('العميل', flex: 2),
        const ReportColumn('الصافي', type: _money),
        const ReportColumn('المدفوع', type: _money),
        const ReportColumn('المتبقي', type: _money),
        if (showCost) const ReportColumn('التكلفة', type: _money),
        if (showCost) const ReportColumn('الربح', type: _money),
        const ReportColumn('الحالة'),
      ],
      rows: [
        for (final i in invoices)
          [
            i.number,
            i.date,
            i.partyName,
            i.total,
            i.paid,
            i.remaining,
            if (showCost) i.totalCost,
            if (showCost) i.grossProfit,
            _status(i),
          ],
      ],
      routes: [for (final i in invoices) '/sales/${i.id}'],
      note: 'الفواتير الملغاة معروضة للاطلاع ومستبعدة من الإجماليات.',
    );
  }

  static ReportData purchases(List<Invoice> invoices) {
    final active = invoices.where((i) => !i.cancelled).toList();
    int sum(int Function(Invoice) f) => active.fold<int>(0, (s, i) => s + f(i));
    return ReportData(
      kpis: [
        ReportKpi('إجمالي المشتريات', sum((i) => i.total), tone: Tone.warning),
        ReportKpi('المدفوع', sum((i) => i.paid), tone: Tone.success),
        ReportKpi('المتبقي', sum((i) => i.remaining), tone: Tone.danger),
        ReportKpi('عدد الفواتير', active.length, tone: Tone.neutral, isMoney: false),
      ],
      columns: const [
        ReportColumn('رقم الفاتورة'),
        ReportColumn('التاريخ', type: CellType.date),
        ReportColumn('المورد', flex: 2),
        ReportColumn('الصافي', type: _money),
        ReportColumn('المدفوع', type: _money),
        ReportColumn('المتبقي', type: _money),
        ReportColumn('الحالة'),
      ],
      rows: [
        for (final i in invoices) [i.number, i.date, i.partyName, i.total, i.paid, i.remaining, _status(i)],
      ],
      routes: [for (final i in invoices) '/purchases/${i.id}'],
      note: 'الفواتير الملغاة معروضة للاطلاع ومستبعدة من الإجماليات.',
    );
  }

  static ReportData expenses(List<Expense> expenses) {
    final active = expenses.where((e) => !e.cancelled).toList();
    final total = active.fold<int>(0, (s, e) => s + e.amount);
    final byCategory = <String, ({int amount, int count})>{};
    for (final e in active) {
      final c = byCategory[e.categoryName];
      byCategory[e.categoryName] = (amount: (c?.amount ?? 0) + e.amount, count: (c?.count ?? 0) + 1);
    }
    final categories = byCategory.entries.toList()..sort((a, b) => b.value.amount.compareTo(a.value.amount));
    final byDay = <DateTime, int>{};
    for (final e in active) {
      final d = Dates.startOfDay(e.date);
      byDay[d] = (byDay[d] ?? 0) + e.amount;
    }
    final days = byDay.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return ReportData(
      kpis: [
        ReportKpi('إجمالي المصروفات', total, tone: Tone.danger),
        ReportKpi('عدد المصروفات', active.length, tone: Tone.neutral, isMoney: false),
        ReportKpi('عدد البنود', categories.length, tone: Tone.neutral, isMoney: false),
      ],
      columns: const [
        ReportColumn('البند', flex: 2),
        ReportColumn('العدد', type: CellType.number),
        ReportColumn('المبلغ', type: _money),
        ReportColumn('النسبة %', type: CellType.number),
      ],
      rows: [
        for (final c in categories)
          [c.key, c.value.count, c.value.amount, total == 0 ? 0 : (c.value.amount * 1000 ~/ total) / 10],
      ],
      footer: ['الإجمالي', active.length, total, total == 0 ? 0 : 100],
      secondaryTitle: 'المصروفات حسب التاريخ',
      secondaryColumns: const [ReportColumn('التاريخ', type: CellType.date), ReportColumn('المبلغ', type: _money)],
      secondaryRows: [for (final d in days) [d.key, d.value]],
    );
  }

  static ReportData balances(List<Party> parties, PartyKind kind) {
    final withBalance = parties.where((p) => p.balance != 0).toList()..sort((a, b) => b.balance.compareTo(a.balance));
    final positive = withBalance.where((p) => p.balance > 0);
    final negative = withBalance.where((p) => p.balance < 0);
    return ReportData(
      kpis: [
        ReportKpi(kind.isCustomer ? 'إجمالي ديون العملاء' : 'إجمالي المستحق للموردين',
            positive.fold<int>(0, (s, p) => s + p.balance), tone: Tone.danger),
        ReportKpi(kind.isCustomer ? 'عدد العملاء المدينين' : 'عدد الموردين الدائنين', positive.length,
            tone: Tone.neutral, isMoney: false),
        if (negative.isNotEmpty)
          ReportKpi(kind.isCustomer ? 'أرصدة دائنة للعملاء' : 'دفعات مقدمة للموردين',
              negative.fold<int>(0, (s, p) => s + p.balance), tone: Tone.info),
      ],
      columns: [
        ReportColumn(kind.isCustomer ? 'العميل' : 'المورد', flex: 2),
        const ReportColumn('الهاتف'),
        const ReportColumn('الفواتير', type: CellType.number),
        const ReportColumn('آخر حركة', type: CellType.date),
        const ReportColumn('الرصيد', type: _money),
      ],
      rows: [
        for (final p in withBalance) [p.name, p.phone, p.invoiceCount, p.lastTxAt, p.balance],
      ],
      footer: ['الإجمالي', '', null, null, withBalance.fold<int>(0, (s, p) => s + p.balance)],
      routes: [for (final p in withBalance) '${kind.route}/${p.id}'],
    );
  }

  /// Opening = current balance − Σ movements since the start of the range;
  /// closing = opening + Σ movements inside the range.
  static ReportData cashboxes(List<Cashbox> boxes, List<CashMove> movesSinceFrom, DateRange range) {
    final rows = <List<Object?>>[];
    var tOpen = 0, tIn = 0, tOut = 0, tTin = 0, tTout = 0, tClose = 0;
    for (final b in boxes) {
      final since = movesSinceFrom.where((m) => m.cashboxId == b.id).toList();
      final opening = b.balance - since.fold<int>(0, (s, m) => s + m.amount);
      final inRange = since.where((m) => range.contains(m.date));
      int pick(bool Function(CashMove) f) => inRange.where(f).fold<int>(0, (s, m) => s + m.amount.abs());
      final income = pick((m) => !m.isTransfer && m.amount > 0);
      final expense = pick((m) => !m.isTransfer && m.amount < 0);
      final tin = pick((m) => m.isTransfer && m.amount > 0);
      final tout = pick((m) => m.isTransfer && m.amount < 0);
      final closing = opening + income - expense + tin - tout;
      rows.add([b.name, opening, income, expense, tin, tout, closing]);
      tOpen += opening;
      tIn += income;
      tOut += expense;
      tTin += tin;
      tTout += tout;
      tClose += closing;
    }
    return ReportData(
      kpis: [
        ReportKpi('رصيد أول المدة', tOpen, tone: Tone.neutral),
        ReportKpi('الوارد', tIn, tone: Tone.success),
        ReportKpi('المنصرف', tOut, tone: Tone.danger),
        ReportKpi('رصيد آخر المدة', tClose, tone: Tone.primary),
      ],
      columns: const [
        ReportColumn('الخزنة', flex: 2),
        ReportColumn('أول المدة', type: _money),
        ReportColumn('الوارد', type: _money),
        ReportColumn('المنصرف', type: _money),
        ReportColumn('تحويلات واردة', type: _money),
        ReportColumn('تحويلات صادرة', type: _money),
        ReportColumn('آخر المدة', type: _money),
      ],
      rows: rows,
      footer: ['الإجمالي', tOpen, tIn, tOut, tTin, tTout, tClose],
      routes: [for (final b in boxes) '/cashboxes/${b.id}'],
      note: 'التحويلات بين الخزائن لا تغير إجمالي النقدية ولا تُحتسب إيراداً أو مصروفاً.',
    );
  }

  static ReportData services(List<SoldItem> items) {
    final groups = <String, ({String name, double qty, int net, int cost})>{};
    for (final i in items.where((i) => i.kind == LineKind.service)) {
      final g = groups[i.itemId];
      groups[i.itemId] = (
        name: i.name,
        qty: (g?.qty ?? 0) + i.quantity,
        net: (g?.net ?? 0) + i.net,
        cost: (g?.cost ?? 0) + i.cost,
      );
    }
    final list = groups.values.toList()..sort((a, b) => b.net.compareTo(a.net));
    final revenue = list.fold<int>(0, (s, g) => s + g.net);
    final cost = list.fold<int>(0, (s, g) => s + g.cost);
    final qty = list.fold(0.0, (s, g) => s + g.qty);
    double margin(int net, int c) => net == 0 ? 0 : ((net - c) * 1000 ~/ net) / 10;
    return ReportData(
      kpis: [
        ReportKpi('عدد الخدمات المباعة', qty, tone: Tone.neutral, isMoney: false),
        ReportKpi('إيراد الخدمات', revenue, tone: Tone.info),
        ReportKpi('تكلفة الخدمات', cost, tone: Tone.warning),
        ReportKpi('ربح الخدمات', revenue - cost, tone: Tone.success),
        ReportKpi('هامش الربح %', margin(revenue, cost), tone: Tone.success, isMoney: false),
      ],
      columns: const [
        ReportColumn('الخدمة', flex: 2),
        ReportColumn('العدد', type: CellType.number),
        ReportColumn('الإيراد', type: _money),
        ReportColumn('التكلفة', type: _money),
        ReportColumn('الربح', type: _money),
        ReportColumn('الهامش %', type: CellType.number),
      ],
      rows: [
        for (final g in list) [g.name, g.qty, g.net, g.cost, g.net - g.cost, margin(g.net, g.cost)],
      ],
      footer: ['الإجمالي', qty, revenue, cost, revenue - cost, margin(revenue, cost)],
      note: 'الإيراد بعد توزيع خصم الفاتورة على الأصناف بالتناسب.',
    );
  }

  static ReportData products(List<Product> products) {
    final active = products.where((p) => p.active).toList()..sort((a, b) => a.name.compareTo(b.name));
    int value(Product p) => p.stockQty <= 0 ? 0 : Money.multiply(p.stockQty, p.costPrice);
    final total = active.fold<int>(0, (s, p) => s + value(p));
    return ReportData(
      kpis: [
        ReportKpi('قيمة المخزون بالتكلفة', total, tone: Tone.primary),
        ReportKpi('عدد المنتجات', active.length, tone: Tone.neutral, isMoney: false),
        ReportKpi('منتجات نفد مخزونها', active.where((p) => p.stockQty <= 0).length, tone: Tone.danger, isMoney: false),
        ReportKpi('مخزون منخفض', active.where((p) => p.isLowStock).length, tone: Tone.warning, isMoney: false),
      ],
      columns: const [
        ReportColumn('المنتج', flex: 2),
        ReportColumn('الكمية', type: CellType.number),
        ReportColumn('متوسط التكلفة', type: _money),
        ReportColumn('سعر البيع', type: _money),
        ReportColumn('قيمة المخزون', type: _money),
      ],
      rows: [for (final p in active) [p.name, p.stockQty, p.costPrice, p.sellPrice, value(p)]],
      footer: ['الإجمالي', null, null, null, total],
    );
  }

  static String _status(Invoice i) => i.cancelled
      ? 'ملغاة'
      : switch (i.paymentStatus) {
          PaymentStatus.paid => 'مدفوعة',
          PaymentStatus.partial => 'جزئية',
          PaymentStatus.unpaid => 'آجلة',
        };
}

extension on PostingMetrics {
  /// True when the bucket had any activity (keeps profit tables compact).
  bool get txCountLike =>
      sales != 0 || productCost != 0 || serviceCost != 0 || expenses != 0 || purchases != 0;
}
