import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import '../models/person.dart';
import '../models/ledger_transaction.dart';
import '../models/transaction_type.dart';
import '../utils/money.dart';
import '../utils/date_utils.dart';

/// Generates PDF ledger statements and payment reminder text messages.
/// Uses a Unicode-capable font loaded at runtime so Bangla text renders
/// correctly in the exported PDF.
class PdfService {
  pw.Font? _bengaliFont;

  Future<pw.Font> _loadFont() async {
    if (_bengaliFont != null) return _bengaliFont!;
    final data = await rootBundle.load(
      'assets/fonts/NotoSansBengali-Regular.ttf',
    );
    _bengaliFont = pw.Font.ttf(data);
    return _bengaliFont!;
  }

  Future<File> generatePersonLedgerPdf({
    required Person person,
    required List<LedgerTransaction> transactions,
    required int currentBalancePaisa,
  }) async {
    final font = await _loadFont();
    final doc = pw.Document();

    int running = 0;
    final rows = <List<String>>[];
    for (final t in transactions) {
      running += t.balanceDeltaPaisa;
      rows.add([
        AppDateUtils.formatDate(t.date),
        t.type.labelBn,
        Money.formatPaisa(t.amountPaisa),
        Money.formatPaisa(running),
        t.note ?? '',
      ]);
    }

    doc.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: font, bold: font),
        build: (context) => [
          pw.Text(
            'দেনা পাওনা - লেনদেনের বিবরণী',
            style: pw.TextStyle(font: font, fontSize: 20),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'ব্যক্তি: ${person.name}',
            style: pw.TextStyle(font: font, fontSize: 14),
          ),
          if (person.phone != null)
            pw.Text(
              'ফোন: ${person.phone}',
              style: pw.TextStyle(font: font, fontSize: 12),
            ),
          pw.SizedBox(height: 4),
          pw.Text(
            'বর্তমান ব্যালেন্স: ${Money.formatPaisa(currentBalancePaisa)} '
            '${currentBalancePaisa >= 0 ? '(পাবো)' : '(দেবো)'}',
            style: pw.TextStyle(
              font: font,
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Table.fromTextArray(
            headers: ['তারিখ', 'ধরন', 'পরিমাণ', 'ব্যালেন্স', 'নোট'],
            data: rows,
            headerStyle: pw.TextStyle(
              font: font,
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: pw.TextStyle(font: font, fontSize: 9),
            cellAlignment: pw.Alignment.centerLeft,
            headerDecoration: const pw.BoxDecoration(color: PdfColors.teal100),
          ),
        ],
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/ledger_${person.name}_$timestamp.pdf');
    await file.writeAsBytes(await doc.save());
    return file;
  }

  Future<File> generateReportPdf({
    required List<List<String>> rows,
    required int totalReceivedPaisa,
    required int totalPaidPaisa,
  }) async {
    final font = await _loadFont();
    final doc = pw.Document();
    final now = DateTime.now();
    final netBalancePaisa = totalReceivedPaisa - totalPaidPaisa;
    final dateLabel =
        '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}/${now.year}';
    doc.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: font, bold: font),
        build: (context) => [
          pw.Text(
            'Dena Pawna / দেনা পাওনা',
            style: pw.TextStyle(font: font, fontSize: 20),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Report date: $dateLabel',
            style: pw.TextStyle(font: font, fontSize: 11),
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _summaryCard('Total Received', totalReceivedPaisa, font),
              _summaryCard('Total Paid', totalPaidPaisa, font),
              _summaryCard('Net Balance', netBalancePaisa, font),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Table.fromTextArray(
            headers: const [
              'Date',
              'Person / Note',
              'Payment Method',
              'Type',
              'Amount',
            ],
            data: rows,
            headerStyle: pw.TextStyle(
              font: font,
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: pw.TextStyle(font: font, fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.teal100),
          ),
        ],
      ),
    );
    final dir = await _reportDirectory();
    final timestamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}';
    final file = File('${dir.path}/DenaPawna_Report_$timestamp.pdf');
    await file.writeAsBytes(await doc.save());
    return file;
  }

  pw.Widget _summaryCard(String label, int amountPaisa, pw.Font font) {
    return pw.Container(
      width: 160,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.teal200),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: pw.TextStyle(font: font, fontSize: 9)),
          pw.SizedBox(height: 3),
          pw.Text(
            Money.formatPaisa(amountPaisa),
            style: pw.TextStyle(font: font, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Future<Directory> _reportDirectory() async {
    if (!kIsWeb && Platform.isAndroid) {
      final downloads = Directory('/storage/emulated/0/Download');
      if (!await downloads.exists()) await downloads.create(recursive: true);
      return downloads;
    }
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) {
        if (!await downloads.exists()) await downloads.create(recursive: true);
        return downloads;
      }
    }
    return getApplicationDocumentsDirectory();
  }

  /// Generates a friendly Bangla payment reminder message for sharing
  /// via WhatsApp/SMS/Messenger etc.
  String generateReminderMessage({
    required Person person,
    required int balancePaisa,
  }) {
    final amount = Money.formatPaisa(balancePaisa.abs());
    if (balancePaisa > 0) {
      return 'প্রিয় ${person.name}, আপনার কাছে আমার $amount টাকা বাকি আছে। '
          'সময় করে পরিশোধ করলে ভালো হয়। ধন্যবাদ। - দেনা পাওনা';
    } else if (balancePaisa < 0) {
      return 'প্রিয় ${person.name}, আপনাকে আমার $amount টাকা দেওয়া বাকি আছে। '
          'শীঘ্রই পরিশোধ করে দিবো। ধন্যবাদ। - দেনা পাওনা';
    } else {
      return '${person.name}, আপনার সাথে আমার হিসাব সম্পূর্ণ পরিশোধ করা আছে। ধন্যবাদ। - দেনা পাওনা';
    }
  }
}
