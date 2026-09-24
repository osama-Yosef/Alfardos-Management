import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/module_colors.dart';
import '../../core/widgets/responsive.dart';
import '../../features/auth/application/auth_providers.dart';
import '../navigation.dart';
import 'app_sidebar.dart';
import 'top_bar.dart';

/// Adaptive application frame.
///
/// * Desktop (≥1100): full sidebar on the right (RTL) + top bar.
/// * Tablet: compact icon sidebar + top bar.
/// * Phone: bottom navigation bar with a "more" menu; pages bring their own
///   app bar.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return child;
    final module = AppNav.match(location, includeExtra: true) ?? AppNav.dashboard;
    final page = ModuleScope(icon: module.icon, color: module.color, child: child);

    if (context.isMobile) {
      final items = AppNav.mobilePrimary.where((i) => i.visibleFor(user)).toList();
      final current = AppNav.match(location);
      var index = items.indexWhere((i) => i.path == current?.path);
      if (index < 0) index = items.length; // "more"
      final selectedColor = index < items.length ? items[index].color : AppColors.primary;
      return Scaffold(
        body: page,
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          indicatorColor: ModuleColors.soft(selectedColor),
          onDestinationSelected: (i) {
            if (i == items.length) {
              context.go('/more');
            } else {
              context.go(items[i].path);
            }
          },
          destinations: [
            for (final item in items)
              NavigationDestination(
                icon: Icon(item.icon, color: item.color.withValues(alpha: 0.75)),
                selectedIcon: Icon(item.icon, fill: 1, color: item.color),
                label: item.label,
              ),
            const NavigationDestination(icon: Icon(Symbols.menu), label: 'المزيد'),
          ],
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          AppSidebar(location: location, compact: !context.isDesktop),
          const VerticalDivider(width: 1, color: AppColors.border),
          Expanded(
            child: Column(
              children: [
                const TopBar(),
                Expanded(child: page),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
