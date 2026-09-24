import '../money/money.dart';

/// Builds `keywords` arrays for prefix search in Firestore
/// (`where('keywords', arrayContains: term)`), since Firestore has no
/// full-text search. Every word contributes its prefixes (up to 12 chars).
abstract final class Keywords {
  static List<String> build(Iterable<String?> values) {
    final out = <String>{};
    for (final raw in values) {
      if (raw == null) continue;
      final text = normalize(raw);
      if (text.isEmpty) continue;
      final words = text.split(' ').where((w) => w.isNotEmpty).toList();
      for (final w in [...words, text]) {
        for (var i = 1; i <= w.length && i <= 12; i++) {
          out.add(w.substring(0, i));
        }
      }
    }
    return out.toList();
  }

  /// Lowercase, ASCII digits, unified Arabic letter forms, single spaces.
  static String normalize(String input) {
    var s = Money.normalizeDigits(input.toLowerCase().trim());
    s = s
        .replaceAll(RegExp('[أإآ]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll(RegExp('[ً-ْ]'), '') // tashkeel
        .replaceAll(RegExp(r'\s+'), ' ');
    return s;
  }

  /// Search term to query with (first word, capped at 12 chars).
  static String? term(String query) {
    final n = normalize(query);
    if (n.isEmpty) return null;
    return n.length > 12 ? n.substring(0, 12) : n;
  }
}
