import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/firebase/firebase_providers.dart';
import '../../core/permissions/permissions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/status_badge.dart';
import '../../features/auth/application/auth_providers.dart';
import '../../features/notifications/notifications.dart';
import 'global_search.dart';

class TopBar extends ConsumerWidget {
  const TopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider)!;
    final offline = ref.watch(offlineProvider).value ?? false;
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => GlobalSearch.open(context),
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Row(
                      children: [
                        Icon(Symbols.search, size: 20, color: Colors.black),
                        SizedBox(width: 8),
                        Text('ابحث عن عميل، مورد، صنف أو فاتورة...',
                            style: TextStyle(color: Colors.black, fontSize: 13.5)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (offline) ...[
            const StatusBadge('غير متصل - عرض البيانات المحفوظة', tone: Tone.warning, icon: Symbols.cloud_off),
            const SizedBox(width: 12),
          ],
          if (user.can(Permission.createSales)) ...[
            FilledButton.icon(
              onPressed: () => context.push('/sales/new'),
              icon: const Icon(Symbols.add, size: 20),
              label: const Text('فاتورة بيع'),
            ),
            const SizedBox(width: 8),
          ],
          const NotificationBell(),
          const SizedBox(width: 4),
          const UserMenu(),
        ],
      ),
    );
  }
}

class UserMenu extends ConsumerWidget {
  const UserMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider)!;
    return PopupMenuButton<String>(
      tooltip: 'حسابي',
      position: PopupMenuPosition.under,
      onSelected: (v) async {
        if (v == 'profile') context.push('/profile');
        if (v == 'logout') await ref.read(authRepositoryProvider).signOut();
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user.name, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              Text('${user.roleName} • ${user.email}', style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'profile', child: ListTile(leading: Icon(Symbols.person), title: Text('الملف الشخصي'))),
        const PopupMenuItem(value: 'logout', child: ListTile(leading: Icon(Symbols.logout), title: Text('تسجيل الخروج'))),
      ],
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.primarySoft,
          child: Text(
            user.name.isEmpty ? '?' : user.name.characters.first,
            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
