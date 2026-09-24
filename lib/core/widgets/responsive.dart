import 'package:flutter/widgets.dart';

/// Layout breakpoints (logical pixels).
abstract final class Breakpoints {
  static const tablet = 700.0;
  static const desktop = 1100.0;
}

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  bool get isMobile => screenWidth < Breakpoints.tablet;
  bool get isTablet => screenWidth >= Breakpoints.tablet && screenWidth < Breakpoints.desktop;
  bool get isDesktop => screenWidth >= Breakpoints.desktop;

  /// Horizontal page padding appropriate for the current width.
  double get pagePadding => isMobile ? 16 : 24;
}

/// Chooses a builder by available width.
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  final WidgetBuilder mobile;
  final WidgetBuilder? tablet;
  final WidgetBuilder? desktop;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth >= Breakpoints.desktop) return (desktop ?? tablet ?? mobile)(context);
      if (c.maxWidth >= Breakpoints.tablet) return (tablet ?? mobile)(context);
      return mobile(context);
    });
  }
}

/// A wrap-based grid whose column count adapts to the available width.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = 220,
    this.spacing = 12,
    this.maxColumns = 4,
  });

  final List<Widget> children;
  final double minItemWidth;
  final double spacing;
  final int maxColumns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      var columns = ((c.maxWidth + spacing) / (minItemWidth + spacing)).floor();
      columns = columns.clamp(1, maxColumns);
      final width = (c.maxWidth - spacing * (columns - 1)) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    });
  }
}
