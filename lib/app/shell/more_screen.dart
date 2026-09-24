import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/module_colors.dart';
import '../../core/widgets/page_scaffold.dart';
import '../../features/auth/application/auth_providers.dart';
import '../../features/notifications/notifications.dart';
import '../navigation.dart';

/// Phone "more" menu: every destination not in the bottom bar.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider)!;
    return PageScaffold(
      title: 'المزيد',
      actions: const [NotificationBell()],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.primarySoft,
                child: Icon(Symbols.person, color: AppColors.primary),
              ),
              title: Text(user.name),
              subtitle: Text(user.roleName),
              trailing: const Icon(Symbols.chevron_left),
              onTap: () => context.push('/profile'),
            ),
          ),
          for (final group in AppNav.groups)
            if (group.label != null)
              ..._group(context, group, user),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Symbols.logout, color: AppColors.danger),
              title: const Text('تسجيل الخروج', style: TextStyle(color: AppColors.danger)),
              onTap: () => ref.read(authRepositoryProvider).signOut(),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _group(BuildContext context, NavGroup group, user) {
    final items = group.items.where((i) => i.visibleFor(user)).toList();
    if (items.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
        child: Text(group.label!, style: Theme.of(context).textTheme.titleSmall),
      ),
      Card(
        child: Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const Divider(indent: 56),
              ListTile(
                leading: ModuleIcon(icon: items[i].icon, color: items[i].color, size: 34),
                title: Text(items[i].label),
                trailing: const Icon(Symbols.chevron_left),
                onTap: () => context.go(items[i].path),
              ),
            ],
          ],
        ),
      ),
    ];
  }
}
