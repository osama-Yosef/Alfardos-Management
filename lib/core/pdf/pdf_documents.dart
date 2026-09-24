import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../features/invoices/domain/invoice.dart';
import '../accounting/invoice_calculator.dart';
import '../accounting/statement.dart';
import '../money/money.dart';
import '../settings/company_settings.dart';
import '../utils/dates.dart';
import 'pdf_kit.dart';

/// Tabular report definition rendered to PDF.
class ReportTable {
  const ReportTable({
    required this.headers,
    required this.rows,
    this.numeric = const {},
    this.footer,
    this.title,
  });

  final String? title;
  final List<String> headers;
  final List<List<String>> rows;
  final Set<int> numeric;
  final List<String>? footer;
}

abstract final class PdfDocuments {
  static Future<Uint8List> invoice(Invoice inv, CompanySettings settings) async {
    final kit = await PdfKit.load(settings);
    final doc = pw.Document(title: '${inv.kind.title} ${inv.number}', author: settings.companyName);
    final receipt = settings.paperSize == PaperSize.receipt80;
    final status = inv.cancelled
        ? 'ملغاة'
        : switch (inv.paymentStatus) {
            PaymentStatus.paid => 'مدفوعة',
            PaymentStatus.partial => 'مدفوعة جزئياً',
            PaymentStatus.unpaid => 'آجلة',
          };

    final meta = [
      pw.Text('رقم: ${inv.number}', style: const pw.TextStyle(fontSize: 10)),
      pw.Text('التاريخ: ${Dates.format(inv.date)}', style: const pw.TextStyle(fontSize: 10)),
      pw.Text('الحالة: $status', style: const pw.TextStyle(fontSize: 10)),
    ];

    final lineRows = [
      for (var i = 0; i < inv.lines.length; i++)
        [
          '${i + 1}',
          inv.lines[i].name + (inv.lines[i].kind == LineKind.service ? ' (خدمة)' : ''),
          formatQuantity(inv.lines[i].quantity),
          kit.m(inv.lines[i].unitPrice),
          kit.m(inv.lines[i].gross),
        ],
    ];

    final totals = <(String, String)>[
      ('الإجمالي', kit.m(inv.subtotal)),
      if (inv.discount > 0) ('الخصم', kit.m(inv.discount)),
      ('الصافي', kit.m(inv.total)),
      ('المدفوع', kit.m(inv.paid)),
      ('المتبقي', kit.m(inv.remaining)),
    ];

    if (receipt) {
      doc.addPage(pw.Page(
        pageTheme: kit.pageTheme(format: PdfPageFormat.roll80, compact: true),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Center(child: pw.Text(settings.companyName, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold))),
            if (settings.phone.isNotEmpty) pw.Center(child: pw.Text(settings.phone, style: const pw.TextStyle(fontSize: 8))),
            pw.SizedBox(height: 4),
            pw.Center(child: pw.Text('${inv.kind.title} ${inv.number}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
            pw.Center(child: pw.Text(Dates.formatTime(inv.date), style: const pw.TextStyle(fontSize: 8))),
            pw.Text('${inv.kind.partyLabel}: ${inv.partyName}', style: const pw.TextStyle(fontSize: 9)),
            pw.Divider(),
            kit.table(headers: ['الصنف', 'كمية', 'المبلغ'], rows: [
              for (final l in inv.lines) [l.name, formatQuantity(l.quantity), kit.m(l.gross)],
            ], numeric: {1, 2}, fontSize: 8),
            pw.SizedBox(height: 4),
            kit.summary(totals, width: double.infinity),
            pw.SizedBox(height: 6),
            pw.Center(child: pw.Text(settings.invoiceFooter, style: const pw.TextStyle(fontSize: 8))),
          ],
        ),
      ));
      return doc.save();
    }

    doc.addPage(pw.MultiPage(
      pageTheme: kit.pageTheme(),
      header: (_) => kit.header(title: inv.kind.title, meta: meta),
      footer: kit.footer,
      build: (ctx) => [
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: const pw.BoxDecoration(color: PdfKit.soft, borderRadius: pw.BorderRadius.all(pw.Radius.circular(6))),
          child: pw.Row(children: [
            pw.Expanded(child: pw.Text('${inv.kind.partyLabel}: ${inv.partyName}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
            if (inv.paid > 0 && inv.cashboxName.isNotEmpty)
              pw.Text('طريقة الدفع: ${inv.method.label} - ${inv.cashboxName}', style: const pw.TextStyle(fontSize: 9)),
          ]),
        ),
        pw.SizedBox(height: 12),
        kit.table(
          headers: ['#', 'الصنف', 'الكمية', 'السعر', 'الإجمالي'],
          rows: lineRows,
          numeric: {2, 3, 4},
          widths: {
            0: const pw.FixedColumnWidth(24),
            1: const pw.FlexColumnWidth(4),
            2: const pw.FlexColumnWidth(1.2),
            3: const pw.FlexColumnWidth(1.6),
            4: const pw.FlexColumnWidth(1.8),
          },
        ),
        pw.SizedBox(height: 12),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (inv.notes.isNotEmpty) pw.Text('ملاحظات: ${inv.notes}', style: const pw.TextStyle(fontSize: 9)),
                  if (inv.cancelled && inv.cancelReason != null)
                    pw.Text('سبب الإلغاء: ${inv.cancelReason}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.red)),
                ],
              ),
            ),
            kit.summary(totals),
          ],
        ),
        pw.SizedBox(height: 24),
        pw.Center(child: pw.Text(settings.invoiceFooter, style: const pw.TextStyle(fontSize: 10, color: PdfKit.muted))),
      ],
    ));
    return doc.save();
  }

  static Future<Uint8List> statement({
    required CompanySettings settings,
    required String title,
    required String accountName,
    required DateRange range,
    required Statement statement,
    required String increaseLabel,
    required String decreaseLabel,
  }) async {
    final kit = await PdfKit.load(settings);
    final doc = pw.Document(title: title, author: settings.companyName);
    doc.addPage(pw.MultiPage(
      pageTheme: kit.pageTheme(),
      header: (_) => kit.header(title: title, subtitle: accountName, meta: [
        pw.Text('الفترة: ${range.label}', style: const pw.TextStyle(fontSize: 10)),
      ]),
      footer: kit.footer,
      build: (_) => [
        kit.table(
          headers: ['التاريخ', 'البيان', 'المرجع', increaseLabel, decreaseLabel, 'الرصيد'],
          numeric: {3, 4, 5},
          widths: {
            0: const pw.FlexColumnWidth(1.4),
            1: const pw.FlexColumnWidth(4),
            2: const pw.FlexColumnWidth(1.4),
            3: const pw.FlexColumnWidth(1.5),
            4: const pw.FlexColumnWidth(1.5),
            5: const pw.FlexColumnWidth(1.6),
          },
          rows: [
            ['', 'رصيد أول المدة', '', '', '', kit.m(statement.opening)],
            for (final r in statement.rows)
              [
                Dates.format(r.entry.date),
                r.entry.description,
                r.entry.reference ?? '',
                r.entry.increase == 0 ? '' : kit.m(r.entry.increase),
                r.entry.decrease == 0 ? '' : kit.m(r.entry.decrease),
                kit.m(r.balance),
              ],
          ],
          footerRow: ['', 'الإجمالي', '', kit.m(statement.totalIncrease), kit.m(statement.totalDecrease), kit.m(statement.closing)],
        ),
      ],
    ));
    return doc.save();
  }

  static Future<Uint8List> report({
    required CompanySettings settings,
    required String title,
    required String subtitle,
    List<(String, String)> summary = const [],
    List<ReportTable> tables = const [],
  }) async {
    final kit = await PdfKit.load(settings);
    final doc = pw.Document(title: title, author: settings.companyName);
    doc.addPage(pw.MultiPage(
      pageTheme: kit.pageTheme(),
      header: (_) => kit.header(title: title, subtitle: subtitle),
      footer: kit.footer,
      build: (_) => [
        if (summary.isNotEmpty) ...[
          kit.summary(summary, width: 300, emphasizeLast: false),
          pw.SizedBox(height: 14),
        ],
        for (final t in tables) ...[
          if (t.title != null)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Text(t.title!, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
            ),
          kit.table(headers: t.headers, rows: t.rows, numeric: t.numeric, footerRow: t.footer),
          pw.SizedBox(height: 14),
        ],
      ],
    ));
    return doc.save();
  }
}
