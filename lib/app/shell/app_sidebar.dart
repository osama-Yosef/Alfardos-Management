import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/module_colors.dart';
import '../../features/auth/application/auth_providers.dart';
import '../../features/settings/application/settings_providers.dart';
import '../navigation.dart';

class AppSidebar extends ConsumerWidget {
  const AppSidebar({super.key, required this.location, this.compact = false});

  final String location;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider)!;
    final company = ref.watch(companySettingsProvider).companyName;
    final current = AppNav.match(location);
    final t = Theme.of(context).textTheme;

    return Container(
      width: compact ? 76 : 256,
      color: AppColors.surface,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(compact ? 12 : 18, 18, compact ? 12 : 18, 14),
            child: Row(
              mainAxisAlignment: compact ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Image.asset('assets/branding/logo_mark.png', width: 40, height: 40),
                if (!compact) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('الفردوس للإدارة', style: t.titleSmall, maxLines: 1),
                        Text(company, style: t.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (final group in AppNav.groups)
                  ..._group(context, group, user, current),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _group(BuildContext context, NavGroup group, user, NavItem? current) {
    final items = group.items.where((i) => i.visibleFor(user)).toList();
    if (items.isEmpty) return const [];
    return [
      if (group.label != null)
        compact
            ? const Padding(padding: EdgeInsets.symmetric(vertical: 6, horizontal: 20), child: Divider())
            : Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(22, 14, 16, 6),
                child: Text(group.label!,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
              ),
      for (final item in items) _SidebarTile(item: item, selected: item == current, compact: compact),
    ];
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({required this.item, required this.selected, required this.compact});

  final NavItem item;
  final bool selected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tile = Material(
      color: selected ? ModuleColors.soft(item.color) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => context.go(item.path),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 8, vertical: 6),
          child: Row(
            mainAxisAlignment: compact ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              ModuleIcon(icon: item.icon, color: item.color, size: 32, solid: selected),
              if (!compact) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: selected ? item.color : AppColors.textPrimary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (selected)
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(color: item.color, borderRadius: BorderRadius.circular(2)),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: compact ? Tooltip(message: item.label, child: tile) : tile,
    );
  }
}
