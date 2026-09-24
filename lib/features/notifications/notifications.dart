import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/firebase/collections.dart';
import '../../core/firebase/firebase_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/dates.dart';
import '../../core/widgets/dialogs.dart';
import '../../core/widgets/live_query_list.dart';
import '../../core/widgets/page_scaffold.dart';
import '../../core/widgets/states.dart';
import '../auth/application/auth_providers.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.read,
    this.route,
    this.createdAt,
  });

  final String id;
  final String kind;
  final String title;
  final String body;
  final bool read;
  final String? route;
  final DateTime? createdAt;

  factory AppNotification.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? const {};
    return AppNotification(
      id: d.id,
      kind: m['kind'] as String? ?? '',
      title: m['title'] as String? ?? '',
      body: m['body'] as String? ?? '',
      read: m['read'] as bool? ?? false,
      route: m['route'] as String?,
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  IconData get icon => switch (kind) {
        'low_cash' => Symbols.account_balance_wallet,
        'large_expense' => Symbols.payments,
        'debt' => Symbols.person_alert,
        _ => Symbols.notifications,
      };

  Tone get tone => switch (kind) {
        'low_cash' => Tone.warning,
        'large_expense' => Tone.danger,
        _ => Tone.info,
      };
}

class NotificationRepository {
  NotificationRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection(Col.notifications);

  Query<Map<String, dynamic>> query() => _col.orderBy('createdAt', descending: true);

  Stream<int> unreadCount() => _col
      .where('read', isEqualTo: false)
      .limit(99)
      .snapshots()
      .map((s) => s.docs.length);

  Future<void> markRead(String id) => _col.doc(id).update({'read': true});

  Future<void> markAllRead() async {
    final unread = await _col.where('read', isEqualTo: false).limit(400).get();
    final batch = _db.batch();
    for (final d in unread.docs) {
      batch.update(d.reference, {'read': true});
    }
    await batch.commit();
  }
}

final notificationRepositoryProvider =
    Provider((ref) => NotificationRepository(ref.watch(firestoreProvider)));

final unreadNotificationsProvider = StreamProvider<int>((ref) {
  if (ref.watch(currentUserProvider) == null) return Stream.value(0);
  return ref.watch(notificationRepositoryProvider).unreadCount();
});

/// Bell with unread badge, used in the top bar.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(unreadNotificationsProvider).value ?? 0;
    return IconButton(
      tooltip: 'الإشعارات',
      onPressed: () => context.push('/notifications'),
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text(count > 98 ? '+99' : '$count'),
        child: const Icon(Symbols.notifications),
      ),
    );
  }
}

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(notificationRepositoryProvider);
    return PageScaffold(
      title: 'الإشعارات',
      maxWidth: 820,
      actions: [
        TextButton.icon(
          onPressed: () => runWithFeedback(context, repo.markAllRead, success: 'تم تعليم الكل كمقروء'),
          icon: const Icon(Symbols.done_all),
          label: const Text('تعليم الكل كمقروء'),
        ),
      ],
      body: LiveQueryList<AppNotification>(
        query: repo.query(),
        fromDoc: AppNotification.fromDoc,
        empty: const EmptyState(
          icon: Symbols.notifications_off,
          title: 'لا توجد إشعارات',
          message: 'ستظهر هنا تنبيهات انخفاض رصيد الخزائن والمصروفات الكبيرة.',
        ),
        itemBuilder: (context, n, _) => ListTile(
          leading: CircleAvatar(
            backgroundColor: n.tone.soft,
            child: Icon(n.icon, color: n.tone.color, size: 20),
          ),
          title: Text(n.title, style: TextStyle(fontWeight: n.read ? FontWeight.w500 : FontWeight.w700)),
          subtitle: Text([n.body, if (n.createdAt != null) Dates.formatTime(n.createdAt!)].join('\n')),
          isThreeLine: true,
          trailing: n.read ? null : const Icon(Icons.circle, size: 10, color: AppColors.primary),
          onTap: () {
            if (!n.read) repo.markRead(n.id);
            if (n.route != null) context.push(n.route!);
          },
        ),
      ),
    );
  }
}
