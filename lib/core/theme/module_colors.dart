import 'package:flutter/material.dart';

/// Each section of the app has its own color so users can tell at a glance
/// where they are (sidebar, page header, cards, quick actions, list icons).
/// Semantic colors (profit green, debt red, ...) stay separate in [Tone].
abstract final class ModuleColors {
  static const dashboard = Color(0xFF3A48B5);
  static const sales = Color(0xFF2563EB);
  static const customers = Color(0xFF0D9488);
  static const receipts = Color(0xFF16A34A);
  static const purchases = Color(0xFFEA7A0C);
  static const suppliers = Color(0xFFB45309);
  static const supplierPayments = Color(0xFFDC5A1E);
  static const cashboxes = Color(0xFF4F46E5);
  static const transfers = Color(0xFF0891B2);
  static const expenses = Color(0xFFDC2626);
  static const services = Color(0xFF9333EA);
  static const products = Color(0xFF0E7490);
  static const reports = Color(0xFFDB2777);
  static const users = Color(0xFF7C3AED);
  static const settings = Color(0xFF475569);
  static const audit = Color(0xFF64748B);

  /// Brand colors taken from the Alfardos logo.
  static const brandTeal = Color(0xFF0F7A6E);
  static const brandGreen = Color(0xFF2E9E5B);
  static const brandGold = Color(0xFFC9A227);

  static Color soft(Color c) => c.withValues(alpha: 0.12);
}

/// The current section (icon + color), provided by the app shell so page
/// headers and accents pick up the section color automatically.
class ModuleScope extends InheritedWidget {
  const ModuleScope({super.key, required this.icon, required this.color, required super.child});

  final IconData icon;
  final Color color;

  static ModuleScope? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<ModuleScope>();

  @override
  bool updateShouldNotify(ModuleScope old) => old.color != color || old.icon != icon;
}

/// Rounded colored square holding an icon — the visual marker of a module.
class ModuleIcon extends StatelessWidget {
  const ModuleIcon({super.key, required this.icon, required this.color, this.size = 36, this.solid = false});

  final IconData icon;
  final Color color;
  final double size;

  /// Solid background with white icon (stronger emphasis).
  final bool solid;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: solid ? color : ModuleColors.soft(color),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(icon, size: size * 0.56, color: solid ? Colors.white : color, fill: solid ? 1 : 0),
    );
  }
}
