import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/audit/audit_entry.dart';
import '../../../core/firebase/collections.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/fields.dart';
import '../../../core/widgets/live_query_list.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/status_badge.dart';

class AuditRecord {
  const AuditRecord({
    required this.id,
    required this.action,
    required this.entityType,
    required this.summary,
    required this.userName,
    required this.platform,
    this.at,
    this.before,
    this.after,
  });

  final String id;
  final AuditAction action;
  final String entityType;
  final String summary;
  final String userName;
  final String platform;
  final DateTime? at;
  final Map<String, dynamic>? before;
  final Map<String, dynamic>? after;

  factory AuditRecord.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? const {};
    return AuditRecord(
      id: d.id,
      action: AuditAction.parse(m['action'] as String? ?? ''),
      entityType: m['entityType'] as String? ?? '',
      summary: m['summary'] as String? ?? '',
      userName: m['userName'] as String? ?? '',
      platform: m['platform'] as String? ?? '',
      at: (m['at'] as Timestamp?)?.toDate(),
      before: (m['before'] as Map?)?.cast<String, dynamic>(),
      after: (m['after'] as Map?)?.cast<String, dynamic>(),
    );
  }

  Tone get tone => switch (action) {
        AuditAction.create || AuditAction.post => Tone.success,
        AuditAction.cancel || AuditAction.delete || AuditAction.deactivate => Tone.danger,
        AuditAction.permissions => Tone.warning,
        AuditAction.login => Tone.neutral,
        _ => Tone.info,
      };
}

/// Immutable history: who did what, when, where, with before/after values.
class AuditLogScreen extends ConsumerStatefulWidget {
  const AuditLogScreen({super.key});

  @override
  ConsumerState<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends ConsumerState<AuditLogScreen> {
  AuditAction? _action;

  static const _entities = {
    Col.sales: 'المبيعات',
    Col.purchases: 'المشتريات',
    Col.customers: 'العملاء',
    Col.suppliers: 'الموردون',
    Col.customerPayments: 'التحصيلات',
    Col.supplierPayments: 'مدفوعات الموردين',
    Col.expenses: 'المصروفات',
    Col.transfers: 'التحويلات',
    Col.cashboxes: 'الخزائن',
    Col.products: 'المنتجات',
    Col.services: 'الخدمات',
    Col.users: 'المستخدمون',
    Col.roles: 'الأدوار',
    Col.settings: 'الإعدادات',
    Col.expenseCategories: 'بنود المصروفات',
    Col.meta: 'النظام',
  };

  @override
  Widget build(BuildContext context) {
    Query<Map<String, dynamic>> q = ref.watch(firestoreProvider).collection(Col.auditLogs);
    if (_action != null) q = q.where('action', isEqualTo: _action!.name);
    q = q.orderBy('at', descending: true);

    return PageScaffold(
      title: 'سجل التدقيق',
      subtitle: 'سجل دائم لا يمكن تعديله أو حذفه',
      body: ListPageBody(
        toolbar: SizedBox(
          width: 280,
          child: AppDropdown<AuditAction?>(
            label: 'نوع العملية',
            items: [null, ...AuditAction.values],
            value: _action,
            itemLabel: (a) => a?.label ?? 'كل العمليات',
            onChanged: (a) => setState(() => _action = a),
          ),
        ),
        child: LiveQueryList<AuditRecord>(
          query: q,
          fromDoc: AuditRecord.fromDoc,
          pageSize: 40,
          empty: const EmptyState(icon: Symbols.history, title: 'لا توجد سجلات'),
          itemBuilder: (context, r, _) => ListTile(
            leading: CircleAvatar(
              backgroundColor: r.tone.soft,
              child: Icon(Symbols.history, size: 20, color: r.tone.color),
            ),
            title: Text(r.summary),
            subtitle: Text(
              [
                r.userName,
                if (r.at != null) Dates.formatTime(r.at!),
                _entities[r.entityType] ?? r.entityType,
                r.platform,
              ].join(' • '),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            trailing: StatusBadge(r.action.label, tone: r.tone),
            onTap: r.before == null && r.after == null
                ? null
                : () => AppDialog.show(
                      context,
                      title: 'تفاصيل التغيير',
                      child: _Diff(before: r.before, after: r.after),
                    ),
          ),
        ),
      ),
    );
  }
}

class _Diff extends StatelessWidget {
  const _Diff({this.before, this.after});
  final Map<String, dynamic>? before;
  final Map<String, dynamic>? after;

  @override
  Widget build(BuildContext context) {
    final enc = JsonEncoder.withIndent('  ', (o) => o.toString());
    Widget block(String title, Map<String, dynamic>? m, Color color) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(8)),
              child: SelectableText(
                m == null ? '-' : enc.convert(m),
                textDirection: TextDirection.ltr,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ],
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        block('قبل', before, AppColors.danger),
        const SizedBox(height: 12),
        block('بعد', after, AppColors.success),
      ],
    );
  }
}
