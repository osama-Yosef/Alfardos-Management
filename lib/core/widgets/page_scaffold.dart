import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/module_colors.dart';
import 'responsive.dart';

/// Standard page frame used by every screen inside the app shell.
///
/// On desktop/tablet the title is rendered as an in-page header (the shell
/// already provides the top bar); on phones it becomes an AppBar with back
/// navigation.
class PageScaffold extends StatelessWidget {
  const PageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.actions = const [],
    this.floatingAction,
    this.scrollable = true,
    this.maxWidth = 1400,
    this.bottomBar,
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget> actions;
  final Widget? floatingAction;

  /// When false, [body] must manage its own scrolling (e.g. a ListView).
  final bool scrollable;
  final double maxWidth;
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    final mobile = context.isMobile;
    final padding = context.pagePadding;
    final t = Theme.of(context).textTheme;

    Widget content = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: body,
      ),
    );
    if (scrollable) {
      content = SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(padding, mobile ? 12 : 4, padding, 96),
        child: content,
      );
    } else {
      content = Padding(
        padding: EdgeInsets.fromLTRB(padding, mobile ? 12 : 4, padding, 0),
        child: content,
      );
    }

    final module = ModuleScope.of(context);
    final accent = module?.color ?? AppColors.primary;

    if (mobile) {
      return Scaffold(
        appBar: AppBar(
          titleSpacing: Navigator.of(context).canPop() ? 0 : 16,
          title: Row(
            children: [
              if (module != null) ...[
                ModuleIcon(icon: module.icon, color: accent, size: 30, solid: true),
                const SizedBox(width: 10),
              ],
              Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
            ],
          ),
          actions: [...actions, const SizedBox(width: 4)],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(3),
            child: Container(height: 3, color: accent),
          ),
        ),
        body: content,
        floatingActionButton: floatingAction,
        bottomNavigationBar: bottomBar,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: EdgeInsets.fromLTRB(padding, 18, padding, 16),
            decoration: BoxDecoration(
              // Soft wash of the section color fading into the page.
              gradient: LinearGradient(
                begin: AlignmentDirectional.centerStart,
                end: AlignmentDirectional.centerEnd,
                colors: [accent.withValues(alpha: 0.10), AppColors.background],
              ),
              border: Border(bottom: BorderSide(color: accent.withValues(alpha: 0.25))),
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Row(
                  children: [
                    if (Navigator.of(context).canPop()) ...[
                      IconButton(
                        tooltip: 'رجوع',
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: Icon(Icons.arrow_back, color: accent),
                      ),
                      const SizedBox(width: 4),
                    ],
                    if (module != null) ...[
                      ModuleIcon(icon: module.icon, color: accent, size: 44, solid: true),
                      const SizedBox(width: 14),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: t.headlineSmall),
                          if (subtitle != null)
                            Text(subtitle!, style: t.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Wrap(spacing: 8, runSpacing: 8, children: actions),
                  ],
                ),
              ),
            ),
          ),
          Expanded(child: content),
          ?bottomBar,
        ],
      ),
      floatingActionButton: floatingAction,
    );
  }
}

/// Wraps a list/table page body: optional toolbar (search, filters) above a
/// card with the content.
class ListPageBody extends StatelessWidget {
  const ListPageBody({super.key, this.toolbar, required this.child, this.summary});

  final Widget? toolbar;
  final Widget? summary;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (summary != null) ...[summary!, const SizedBox(height: 12)],
        if (toolbar != null) ...[toolbar!, const SizedBox(height: 12)],
        child,
      ],
    );
  }
}
