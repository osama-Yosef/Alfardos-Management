import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../money/money.dart';
import '../settings/company_settings.dart';
import '../utils/dates.dart';

/// Shared building blocks for every PDF (invoices, statements, reports):
/// Arabic font, RTL page theme, company header and footer.
class PdfKit {
  PdfKit._(this.theme, this.logo, this.settings, this.money);

  final pw.ThemeData theme;
  final pw.ImageProvider? logo;
  final CompanySettings settings;
  final MoneyFormatter money;

  static pw.Font? _regular;
  static pw.Font? _bold;
  static pw.ImageProvider? _defaultLogo;

  static const primary = PdfColor.fromInt(0xFF3A48B5);
  static const border = PdfColor.fromInt(0xFFDDE1EA);
  static const muted = PdfColor.fromInt(0xFF6B7385);
  static const soft = PdfColor.fromInt(0xFFF3F5F9);

  static Future<PdfKit> load(CompanySettings settings) async {
    _regular ??= pw.Font.ttf(await rootBundle.load('assets/fonts/IBMPlexSansArabic-Regular.ttf'));
    _bold ??= pw.Font.ttf(await rootBundle.load('assets/fonts/IBMPlexSansArabic-Bold.ttf'));
    _defaultLogo ??= pw.MemoryImage(
      (await rootBundle.load('assets/branding/logo_mark.png')).buffer.asUint8List(),
    );
    pw.ImageProvider? logo = _defaultLogo;
    if (settings.logoUrl != null) {
      try {
        logo = await networkImage(settings.logoUrl!);
      } catch (_) {
        // Offline or missing file: fall back to the bundled mark.
      }
    }
    return PdfKit._(
      pw.ThemeData.withFont(base: _regular, bold: _bold),
      logo,
      settings,
      MoneyFormatter(symbol: settings.currencySymbol, decimals: settings.decimals),
    );
  }

  pw.PageTheme pageTheme({PdfPageFormat format = PdfPageFormat.a4, bool compact = false}) => pw.PageTheme(
        pageFormat: format,
        theme: theme,
        textDirection: pw.TextDirection.rtl,
        margin: compact ? const pw.EdgeInsets.all(10) : const pw.EdgeInsets.fromLTRB(32, 28, 32, 28),
      );

  pw.Widget header({required String title, String? subtitle, List<pw.Widget> meta = const []}) {
    final s = settings;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (logo != null) pw.Image(logo!, width: 54, height: 54),
            pw.SizedBox(width: 10),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(s.companyName, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  if (s.address.isNotEmpty) pw.Text(s.address, style: const pw.TextStyle(fontSize: 9, color: muted)),
                  if (s.phone.isNotEmpty) pw.Text('هاتف: ${s.phone}', style: const pw.TextStyle(fontSize: 9, color: muted)),
                  if (s.taxNumber.isNotEmpty)
                    pw.Text('الرقم الضريبي: ${s.taxNumber}', style: const pw.TextStyle(fontSize: 9, color: muted)),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: primary)),
                if (subtitle != null) pw.Text(subtitle, style: const pw.TextStyle(fontSize: 10, color: muted)),
                ...meta,
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Divider(color: border, thickness: 1),
        pw.SizedBox(height: 8),
      ],
    );
  }

  pw.Widget footer(pw.Context context) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 8),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('طُبع في ${Dates.formatTime(DateTime.now())}', style: const pw.TextStyle(fontSize: 8, color: muted)),
            pw.Text('صفحة ${context.pageNumber} من ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 8, color: muted)),
          ],
        ),
      );

  /// Table with a shaded header. [numeric] columns are aligned to the end.
  pw.Widget table({
    required List<String> headers,
    required List<List<String>> rows,
    Set<int> numeric = const {},
    Map<int, pw.TableColumnWidth>? widths,
    List<String>? footerRow,
    double fontSize = 9.5,
  }) {
    pw.Widget cell(String text, int col, {bool header = false, bool bold = false}) => pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
          alignment: numeric.contains(col) ? pw.Alignment.centerLeft : pw.Alignment.centerRight,
          child: pw.Text(
            text,
            style: pw.TextStyle(
              fontSize: header ? fontSize - 0.5 : fontSize,
              fontWeight: header || bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: header ? muted : null,
            ),
          ),
        );
    return pw.Table(
      columnWidths: widths,
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: border, width: 0.5),
        bottom: pw.BorderSide(color: border, width: 0.5),
      ),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: soft),
          children: [for (var i = 0; i < headers.length; i++) cell(headers[i], i, header: true)],
        ),
        for (final r in rows) pw.TableRow(children: [for (var i = 0; i < r.length; i++) cell(r[i], i)]),
        if (footerRow != null)
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: soft),
            children: [for (var i = 0; i < footerRow.length; i++) cell(footerRow[i], i, bold: true)],
          ),
      ],
    );
  }

  /// Label/value summary box (totals, KPIs).
  pw.Widget summary(List<(String, String)> items, {double width = 240, bool emphasizeLast = true}) {
    return pw.Container(
      width: width,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: border),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        children: [
          for (var i = 0; i < items.length; i++)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(items[i].$1, style: const pw.TextStyle(fontSize: 10)),
                  pw.Text(items[i].$2,
                      textDirection: pw.TextDirection.ltr,
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: emphasizeLast && i == items.length - 1 ? pw.FontWeight.bold : null,
                      )),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String m(int minor) => money(minor);
}
