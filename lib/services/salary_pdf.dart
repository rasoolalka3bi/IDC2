import 'package:flutter/material.dart' show BuildContext;
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../app/format.dart';
import '../data/models.dart';
import '../widgets/common.dart';

/// يولّد قصاصة الراتب بصيغة PDF (تحل محل حفظ الصورة في التطبيق القديم).
class SalaryPdf {
  static Future<Uint8List> build(SalarySlip slip) async {
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/IBMPlexSansArabic-Regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/IBMPlexSansArabic-Bold.ttf'));
    final logo = pw.MemoryImage((await rootBundle.load('assets/images/logo.png')).buffer.asUint8List());

    const brand = PdfColor.fromInt(0xFF0F2A44);
    const accent = PdfColor.fromInt(0xFF9A2F63);
    const line = PdfColor.fromInt(0xFFE4E8EE);
    const muted = PdfColor.fromInt(0xFF6B7785);

    final doc = pw.Document(theme: pw.ThemeData.withFont(base: regular, bold: bold));

    pw.Widget group(SalaryGroup g) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 12),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: line), borderRadius: pw.BorderRadius.circular(8)),
          child: pw.Column(children: [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF5F7FA)),
              child: pw.Text(g.title, style: pw.TextStyle(font: bold, fontSize: 11)),
            ),
            for (final i in g.items)
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: line, width: .5))),
                child: pw.Row(children: [
                  pw.Expanded(child: pw.Text(i.label, style: const pw.TextStyle(fontSize: 10, color: muted))),
                  pw.Text(
                    g.kind == SalaryGroupKind.info || i.amount == null ? i.value : money(i.amount!),
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ]),
              ),
          ]),
        );

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      textDirection: pw.TextDirection.rtl,
      margin: const pw.EdgeInsets.all(32),
      build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        pw.Row(children: [
          pw.Image(logo, width: 54, height: 54),
          pw.SizedBox(width: 12),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('شركة الحفر العراقية', style: pw.TextStyle(font: bold, fontSize: 16, color: brand)),
            pw.Text('قصاصة راتب ${monthYear(slip.year, slip.month)}', style: const pw.TextStyle(fontSize: 11, color: muted)),
          ]),
        ]),
        pw.SizedBox(height: 16),
        pw.Container(
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(color: brand, borderRadius: pw.BorderRadius.circular(10)),
          child: pw.Row(children: [
            pw.Expanded(child: pw.Text('صافي الراتب', style: const pw.TextStyle(color: PdfColors.white, fontSize: 12))),
            pw.Text('${money(slip.net)} د.ع', style: pw.TextStyle(font: bold, color: PdfColors.white, fontSize: 18)),
          ]),
        ),
        for (final g in slip.groups) group(g),
        pw.Spacer(),
        pw.Divider(color: line),
        pw.Text('صدرت من تطبيق موظفي شركة الحفر العراقية بتاريخ ${dateStr(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 8, color: accent)),
      ]),
    ));
    return doc.save();
  }

  static String _name(SalarySlip s) => 'salary-${s.year}-${s.month.toString().padLeft(2, '0')}.pdf';

  static Future<void> save(BuildContext context, SalarySlip slip) async {
    try {
      final bytes = await build(slip);
      await Printing.layoutPdf(onLayout: (_) async => bytes, name: _name(slip));
    } catch (_) {
      if (context.mounted) showMessage(context, 'تعذر إنشاء ملف القصاصة');
    }
  }

  static Future<void> share(BuildContext context, SalarySlip slip) async {
    try {
      final bytes = await build(slip);
      await Printing.sharePdf(bytes: bytes, filename: _name(slip));
    } catch (_) {
      if (context.mounted) showMessage(context, 'تعذر مشاركة القصاصة');
    }
  }
}
