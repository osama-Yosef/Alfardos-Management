import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:printing/printing.dart';

import '../widgets/dialogs.dart';

/// Print / share / save for generated PDFs and CSV exports.
abstract final class Exporter {
  static Future<void> printPdf(Uint8List bytes, String name) =>
      Printing.layoutPdf(onLayout: (_) async => bytes, name: name);

  static Future<void> sharePdf(Uint8List bytes, String fileName) =>
      Printing.sharePdf(bytes: bytes, filename: fileName);

  static Future<bool> save(Uint8List bytes, String fileName) async {
    final uri = await FilePicker.saveFile(fileName: fileName, bytes: bytes);
    return uri != null;
  }

  /// CSV with UTF-8 BOM so Excel opens Arabic text correctly.
  static Uint8List csv(List<List<Object?>> rows) {
    final text = Csv(lineDelimiter: '\r\n').encode(rows);
    return Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(text)]);
  }

  /// Bottom sheet / menu offering print, share and save for a PDF built on
  /// demand by [build].
  static Future<void> pdfActions(
    BuildContext context, {
    required String fileName,
    required Future<Uint8List> Function() build,
  }) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Symbols.print), title: const Text('طباعة'), onTap: () => Navigator.pop(ctx, 'print')),
            ListTile(leading: const Icon(Symbols.share), title: const Text('مشاركة'), onTap: () => Navigator.pop(ctx, 'share')),
            ListTile(
              leading: const Icon(Symbols.download),
              title: const Text('حفظ كملف PDF'),
              onTap: () => Navigator.pop(ctx, 'save'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    await runWithFeedback(context, () async {
      final bytes = await build();
      switch (action) {
        case 'print':
          await printPdf(bytes, fileName);
        case 'share':
          await sharePdf(bytes, '$fileName.pdf');
        case 'save':
          final saved = await save(bytes, '$fileName.pdf');
          if (saved && context.mounted) Toast.success(context, 'تم حفظ الملف');
      }
    });
  }

  static Future<void> saveCsv(BuildContext context, String fileName, List<List<Object?>> rows) async {
    await runWithFeedback(context, () async {
      final saved = await save(csv(rows), '$fileName.csv');
      if (saved && context.mounted) Toast.success(context, 'تم تصدير الملف');
    });
  }
}
