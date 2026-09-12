import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import '../models/person.dart';
import '../models/ledger_transaction.dart';
import '../models/transaction_type.dart';
import '../utils/money.dart';
import '../utils/date_utils.dart';

class PdfService {
  pw.Font? _regular;
  pw.Font? _bold;

  Future<void> _loadFonts() async {
    if (_regular != null && _bold != null) return;
    final regular = await rootBundle.load(
      'assets/fonts/Hind_Siliguri-Regular.ttf',
    );
    final bold = await rootBundle.load(
      'assets/fonts/Hind_Siliguri-Bold.ttf',
    );
    _regular = pw.Font.ttf(regular);
    _bold = pw.Font.ttf(bold);
  }

  /// PDF text must remain in logical Unicode order so the embedded Hind
  /// Siliguri font can shape Bangla conjuncts and vowel signs correctly.
  String bn(String? text) {
    return text ?? '';
  }

  // Keep currency text compatible with the embedded report font.
  String money(int paisa) {
    final raw = Money.formatPaisa(paisa);
    return raw.replaceAll('৳', 'Tk ');
  }

  static const PdfColor primary = PdfColor.fromInt(0xFF1E3A8A);
  static const PdfColor green = PdfColor.fromInt(0xFF16A34A);
  static const PdfColor red = PdfColor.fromInt(0xFFDC2626);
  static const PdfColor bg = PdfColor.fromInt(0xFFF8FAFC);
  static const PdfColor border = PdfColor.fromInt(0xFFE2E8F0);

  // ─────────────────────────────────────────────
  // ১) পার্সন লেজার PDF
  // ─────────────────────────────────────────────
  Future<File> generatePersonLedgerPdf({
    required Person person,
    required List<LedgerTransaction> transactions,
    required int currentBalancePaisa,
  }) async {
    await _loadFonts();
    final font = _regular!;
    final fontBold = _bold ?? font;

    final doc = pw.Document();

    int running = 0;
    final rows = <List<String>>[];
    for (final t in transactions) {
      running += t.balanceDeltaPaisa;
      rows.add([
        AppDateUtils.formatDate(t.date),
        bn(t.type.labelBn),
        bn(t.note?.isNotEmpty == true ? t.note! : '-'),
        money(t.amountPaisa),
        money(running),
      ]);
    }

    final isRecv = currentBalancePaisa > 0;
    final isPay = currentBalancePaisa < 0;
    final statusColor = isRecv ? green : (isPay ? red : PdfColors.grey700);
    final statusText = isRecv ? 'পাবো' : (isPay ? 'দেবো' : 'পরিশোধিত');

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 28),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        header: (ctx) => _header(fontBold, font, 'ব্যক্তিগত লেনদেন বিবরণী'),
        footer: (ctx) => _footer(ctx, font),
        build: (ctx) => [
          pw.SizedBox(height: 8),

          // ইনফো কার্ড
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: bg,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: border),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        bn(person.name),
                        style: pw.TextStyle(font: fontBold, fontSize: 16, color: primary),
                      ),
                      if (person.phone != null && person.phone!.isNotEmpty) ...[
                        pw.SizedBox(height: 3),
                        pw.Text(
                          bn('ফোন: ${person.phone}'),
                          style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey800),
                        ),
                      ],
                      pw.SizedBox(height: 3),
                      pw.Text(
                        bn('মোট লেনদেন: ${transactions.length} টি'),
                        style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: pw.BoxDecoration(
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: statusColor, width: 1.2),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        bn('বর্তমান ব্যালেন্স ($statusText)'),
                        style: pw.TextStyle(font: font, fontSize: 9, color: statusColor),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        money(currentBalancePaisa.abs()),
                        style: pw.TextStyle(font: fontBold, fontSize: 15, color: statusColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 16),

          // টেবিল
          pw.TableHelper.fromTextArray(
            headers: [
              bn('তারিখ'),
              bn('ধরন'),
              bn('বিবরণ/নোট'),
              bn('পরিমাণ'),
              bn('ব্যালেন্স'),
            ],
            data: rows,
            border: const pw.TableBorder(
              horizontalInside: pw.BorderSide(color: border, width: 0.5),
              bottom: pw.BorderSide(color: border, width: 0.8),
            ),
            headerStyle: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: primary),
            headerAlignment: pw.Alignment.centerLeft,
            cellStyle: pw.TextStyle(font: font, fontSize: 9),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
            },
            oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF8FAFC)),
          ),
        ],
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final safeName = person.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final file = File('${dir.path}/ledger_${safeName}_$ts.pdf');
    await file.writeAsBytes(await doc.save());
    return file;
  }

  // ─────────────────────────────────────────────
  // ২) সার্বিক রিপোর্ট PDF
  // ─────────────────────────────────────────────
  Future<File> generateReportPdf({
    required List<List<String>> rows,
    required int totalReceivedPaisa,
    required int totalPaidPaisa,
  }) async {
    await _loadFonts();
    final font = _regular!;
    final fontBold = _bold ?? font;
    final doc = pw.Document();
    final net = totalReceivedPaisa - totalPaidPaisa;

    // প্রতিটি সেল বাংলা ফিক্স
    final cleanRows = rows
        .map((r) => r.map((c) => bn(c)).toList())
        .toList();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 28),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        header: (ctx) => _header(fontBold, font, 'সার্বিক হিসাব রিপোর্ট'),
        footer: (ctx) => _footer(ctx, font),
        build: (ctx) => [
          pw.SizedBox(height: 10),

          // সামারি ৩টা কার্ড
          pw.Row(
            children: [
              _card(bn('মোট পেয়েছি'), money(totalReceivedPaisa), green, font, fontBold),
              pw.SizedBox(width: 8),
              _card(bn('মোট দিয়েছি'), money(totalPaidPaisa), red, font, fontBold),
              pw.SizedBox(width: 8),
              _card(bn('নেট ব্যালেন্স'), money(net), primary, font, fontBold),
            ],
          ),

          pw.SizedBox(height: 16),

          pw.TableHelper.fromTextArray(
            headers: [
              bn('তারিখ'),
              bn('ব্যক্তি/বিবরণ'),
              bn('পেমেন্ট'),
              bn('ধরন'),
              bn('পরিমাণ'),
            ],
            data: cleanRows,
            border: const pw.TableBorder(
              horizontalInside: pw.BorderSide(color: border, width: 0.5),
              bottom: pw.BorderSide(color: border, width: 0.8),
            ),
            headerStyle: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: primary),
            cellStyle: pw.TextStyle(font: font, fontSize: 9),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.center,
              3: pw.Alignment.center,
              4: pw.Alignment.centerRight,
            },
            oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF8FAFC)),
          ),
        ],
      ),
    );

    final dir = await _reportDir();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/DenaPawna_Report_$ts.pdf');
    await file.writeAsBytes(await doc.save());
    return file;
  }

  // ─── UI Helpers ───────────────────────────────
  pw.Widget _header(pw.Font bold, pw.Font reg, String title) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: primary, width: 2)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  bn('দেনা পাওনা'),
                  style: pw.TextStyle(font: bold, fontSize: 20, color: primary),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  bn(title),
                  style: pw.TextStyle(font: reg, fontSize: 11, color: PdfColors.grey700),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 12),
          pw.Text(
            bn('তারিখ: ${AppDateUtils.formatDate(DateTime.now())}'),
            style: pw.TextStyle(font: reg, fontSize: 9, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  pw.Widget _footer(pw.Context ctx, pw.Font font) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: border, width: 0.7)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            bn('দেনা পাওনা অ্যাপ দ্বারা প্রস্তুতকৃত'),
            style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600),
          ),
          pw.Text(
            bn('পৃষ্ঠা ${ctx.pageNumber} / ${ctx.pagesCount}'),
            style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  pw.Widget _card(String label, String value, PdfColor color, pw.Font reg, pw.Font bold) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: bg,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: border),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: pw.TextStyle(font: reg, fontSize: 9, color: PdfColors.grey700)),
            pw.SizedBox(height: 4),
            pw.Text(value, style: pw.TextStyle(font: bold, fontSize: 12, color: color)),
          ],
        ),
      ),
    );
  }

  Future<Directory> _reportDir() async {
    if (!kIsWeb && Platform.isAndroid) {
      final d = Directory('/storage/emulated/0/Download');
      if (!await d.exists()) await d.create(recursive: true);
      return d;
    }
    return getApplicationDocumentsDirectory();
  }

  String generateReminderMessage({
    required Person person,
    required int balancePaisa,
  }) {
    final amount = Money.formatPaisa(balancePaisa.abs());
    if (balancePaisa > 0) {
      return 'প্রিয় ${person.name}, আপনার কাছে আমার $amount টাকা পাওনা আছে। সুবিধামত পরিশোধ করবেন। ধন্যবাদ। - দেনা পাওনা';
    } else if (balancePaisa < 0) {
      return 'প্রিয় ${person.name}, আপনার আমার কাছে $amount টাকা পাওনা আছে। শীঘ্রই পরিশোধ করব। ধন্যবাদ। - দেনা পাওনা';
    }
    return '${person.name}, আপনার সাথে হিসাব পরিশোধিত আছে। ধন্যবাদ। - দেনা পাওনা';
  }
}