import 'package:flutter/material.dart';

/// Semantic color palette. Colors carry meaning consistently everywhere:
/// green = profit/income, red = expense/debt/loss, orange = pending/payable,
/// primary indigo = neutral actions and information.
abstract final class AppColors {
  static const primary = Color(0xFF3A48B5);
  static const primaryDark = Color(0xFF2B3690);
  static const primarySoft = Color(0xFFE9EBFA);

  static const background = Color(0xFFF4F6FA);
  static const surface = Colors.white;
  static const surfaceAlt = Color(0xFFF8F9FC);
  static const border = Color(0xFFE3E7EF);
  static const divider = Color(0xFFEDF0F5);

  static const textPrimary = Color(0xFF1B2130);
  static const textSecondary = Color(0xFF5B6475);
  static const textMuted = Color(0xFF8A93A6);

  static const success = Color(0xFF1F8A5B);
  static const successSoft = Color(0xFFE6F4EC);
  static const danger = Color(0xFFC8423F);
  static const dangerSoft = Color(0xFFFBEBEA);
  static const warning = Color(0xFFD27C12);
  static const warningSoft = Color(0xFFFDF1E1);
  static const info = Color(0xFF2E6FD8);
  static const infoSoft = Color(0xFFE7F0FC);
  static const neutral = Color(0xFF6B7385);
  static const neutralSoft = Color(0xFFEEF0F4);

  /// Sequential chart palette (muted, distinguishable).
  static const chart = [
    Color(0xFF3A48B5),
    Color(0xFF1F8A5B),
    Color(0xFFD27C12),
    Color(0xFFC8423F),
    Color(0xFF7A5AC9),
    Color(0xFF1E9AAE),
    Color(0xFF9A6B3F),
    Color(0xFF6B7385),
  ];
}

/// Semantic tones used by badges, stat cards and money text.
enum Tone {
  primary(AppColors.primary, AppColors.primarySoft),
  success(AppColors.success, AppColors.successSoft),
  danger(AppColors.danger, AppColors.dangerSoft),
  warning(AppColors.warning, AppColors.warningSoft),
  info(AppColors.info, AppColors.infoSoft),
  neutral(AppColors.neutral, AppColors.neutralSoft);

  const Tone(this.color, this.soft);
  final Color color;
  final Color soft;
}
