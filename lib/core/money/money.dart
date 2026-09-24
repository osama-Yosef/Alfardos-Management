import 'package:intl/intl.dart';

/// All monetary amounts in the system are stored as integers in *minor units*
/// (1/100 of the currency unit). This avoids floating point drift in
/// accounting calculations: 12.50 is stored as 1250.
///
/// Quantities (which can be fractional, e.g. 1.5 kg) are stored as doubles,
/// and every amount derived from a quantity is rounded back to minor units
/// immediately via [Money.multiply].
abstract final class Money {
  static const int scale = 100;

  /// Converts user input such as "1,250.5" or "١٢٥٠٫٥" to minor units.
  /// Returns null when the input is not a valid number.
  static int? parse(String input) {
    final normalized = normalizeDigits(input)
        .replaceAll(',', '')
        .replaceAll('٬', '')
        .replaceAll('٫', '.')
        .trim();
    if (normalized.isEmpty) return null;
    final value = double.tryParse(normalized);
    if (value == null || value.isNaN || value.isInfinite) return null;
    return (value * scale).round();
  }

  /// Converts Arabic-Indic and Persian digits to ASCII digits.
  static String normalizeDigits(String input) {
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final ch = String.fromCharCode(rune);
      final a = arabic.indexOf(ch);
      final p = persian.indexOf(ch);
      if (a >= 0) {
        buffer.write(a);
      } else if (p >= 0) {
        buffer.write(p);
      } else {
        buffer.write(ch);
      }
    }
    return buffer.toString();
  }

  /// quantity × unit amount, rounded half away from zero to minor units.
  static int multiply(double quantity, int unitAmount) =>
      (quantity * unitAmount).round();

  static double toMajor(int minor) => minor / scale;

  static int fromMajor(num major) => (major * scale).round();

  /// Plain editable representation (no grouping), used to pre-fill inputs.
  static String toInput(int minor) {
    if (minor % scale == 0) return (minor ~/ scale).toString();
    return (minor / scale).toStringAsFixed(2);
  }
}

/// Formats minor-unit amounts for display. Created from company settings so
/// the currency symbol and decimal places are consistent app-wide.
class MoneyFormatter {
  MoneyFormatter({this.symbol = '', this.decimals = 2})
      : _format = NumberFormat.decimalPatternDigits(
          locale: 'en',
          decimalDigits: decimals,
        );

  final String symbol;
  final int decimals;
  final NumberFormat _format;

  String call(int minor, {bool withSymbol = true, bool signed = false}) {
    final text = _format.format(Money.toMajor(minor.abs()));
    final sign = minor < 0 ? '-' : (signed && minor > 0 ? '+' : '');
    if (!withSymbol || symbol.isEmpty) return '$sign$text';
    return '$sign$text $symbol';
  }

  /// Compact form for charts and tight cards: 12.5K, 3.2M.
  String compact(int minor) {
    final major = Money.toMajor(minor);
    return NumberFormat.compact(locale: 'en').format(major);
  }
}

/// Formats quantities without trailing zeros: 2, 1.5, 0.25.
String formatQuantity(double quantity) {
  if (quantity == quantity.roundToDouble()) return quantity.toInt().toString();
  return quantity
      .toStringAsFixed(3)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}
