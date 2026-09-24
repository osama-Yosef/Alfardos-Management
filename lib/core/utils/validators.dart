import '../money/money.dart';

/// Arabic form validators. Each returns null when valid.
abstract final class Validators {
  static String? required(String? v, [String field = 'هذا الحقل']) =>
      (v == null || v.trim().isEmpty) ? '$field مطلوب.' : null;

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'البريد الإلكتروني مطلوب.';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());
    return ok ? null : 'البريد الإلكتروني غير صالح.';
  }

  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'كلمة المرور مطلوبة.';
    if (v.length < 8) return 'كلمة المرور يجب أن تكون 8 أحرف على الأقل.';
    return null;
  }

  static String? phone(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final digits = Money.normalizeDigits(v).replaceAll(RegExp(r'[\s\-+()]'), '');
    return RegExp(r'^\d{6,15}$').hasMatch(digits) ? null : 'رقم الهاتف غير صالح.';
  }

  /// Money amount: [allowZero] for optional amounts such as "paid".
  static String? amount(
    String? v, {
    bool required = true,
    bool allowZero = false,
    bool allowNegative = false,
    int? max,
    String? maxMessage,
  }) {
    if (v == null || v.trim().isEmpty) {
      return required ? 'المبلغ مطلوب.' : null;
    }
    final value = Money.parse(v);
    if (value == null) return 'أدخل رقماً صحيحاً.';
    if (!allowNegative && value < 0) return 'المبلغ لا يمكن أن يكون سالباً.';
    if (!allowZero && value == 0) return 'المبلغ يجب أن يكون أكبر من صفر.';
    if (max != null && value > max) return maxMessage ?? 'المبلغ أكبر من المسموح.';
    return null;
  }

  static String? quantity(String? v) {
    if (v == null || v.trim().isEmpty) return 'الكمية مطلوبة.';
    final q = double.tryParse(Money.normalizeDigits(v).replaceAll('٫', '.'));
    if (q == null) return 'أدخل رقماً صحيحاً.';
    if (q <= 0) return 'الكمية يجب أن تكون أكبر من صفر.';
    return null;
  }

  static double? parseQuantity(String v) =>
      double.tryParse(Money.normalizeDigits(v).replaceAll('٫', '.').trim());
}
