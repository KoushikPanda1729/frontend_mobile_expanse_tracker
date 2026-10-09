import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:expensetracker/data/analysis.dart';
import 'package:expensetracker/data/ledger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

String _d(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String buildCsv(List<Txn> l) {
  final b = StringBuffer('date,type,category,merchant,mode,amount\n');
  for (final t in l) {
    b.writeln('${t.date.toIso8601String().substring(0, 10)},'
        '${t.isIncome ? 'income' : 'expense'},${t.category.name},'
        '"${t.merchant.replaceAll('"', '""')}",${t.mode},${t.amount}');
  }
  return b.toString();
}

// ponytail: standard PDF fonts have no ₹ glyph, so the PDF writes "Rs". Embed a TTF font to get ₹.
Future<Uint8List> buildPdf(List<Txn> l, String period) async {
  final doc = PdfDocument();
  final page = doc.pages.add();
  final title = PdfStandardFont(PdfFontFamily.helvetica, 18, style: PdfFontStyle.bold);
  final body = PdfStandardFont(PdfFontFamily.helvetica, 10);
  String rs(double v) => 'Rs ${v.toStringAsFixed(2)}';

  page.graphics.drawString('Transaction statement', title,
      bounds: const Rect.fromLTWH(0, 0, 500, 26));
  page.graphics.drawString(
    '$period    Income ${rs(Ledger.income(l))}    '
    'Expense ${rs(Ledger.expense(l))}    ${l.length} transactions',
    body,
    bounds: const Rect.fromLTWH(0, 28, 500, 16),
  );

  final grid = PdfGrid()
    ..columns.add(count: 5)
    ..headers.add(1);
  grid.style = PdfGridStyle(
    font: body,
    cellPadding: PdfPaddings(left: 3, right: 3, top: 3, bottom: 3),
  );
  final head = grid.headers[0];
  for (final (i, h) in ['Date', 'Merchant', 'Category', 'Mode', 'Amount'].indexed) {
    head.cells[i].value = h;
    head.cells[i].style.backgroundBrush = PdfSolidBrush(PdfColor(238, 229, 255));
  }
  for (final t in l) {
    final r = grid.rows.add();
    r.cells[0].value = _d(t.date);
    r.cells[1].value = t.merchant;
    r.cells[2].value = t.category.name;
    r.cells[3].value = t.mode;
    r.cells[4].value = '${t.isIncome ? '+' : '-'} ${rs(t.amount)}';
    r.cells[4].stringFormat = PdfStringFormat(alignment: PdfTextAlignment.right);
  }
  grid.draw(page: page, bounds: const Rect.fromLTWH(0, 56, 0, 0));

  final bytes = Uint8List.fromList(await doc.save());
  doc.dispose();
  return bytes;
}

/// Writes the file to a temp dir and opens the share sheet (iOS: "Save to Files").
Future<void> shareFile(Uint8List bytes, String name, String mime) async {
  final dir = await getTemporaryDirectory();
  final f = File('${dir.path}/$name');
  await f.writeAsBytes(bytes);
  await Share.shareXFiles([XFile(f.path, mimeType: mime)], subject: name);
}

// ---------- full analysis report (PDF) ----------

String _rs(double v) => inr(v).replaceAll('₹', 'Rs ');
String _pt(String s) => s.replaceAll('₹', 'Rs ').replaceAll('·', '-');

class _Report {
  final doc = PdfDocument();
  late PdfPage page;
  double y = 0;
  late final double w, bottom;
  final h1 = PdfStandardFont(PdfFontFamily.helvetica, 20, style: PdfFontStyle.bold);
  final h2 = PdfStandardFont(PdfFontFamily.helvetica, 13, style: PdfFontStyle.bold);
  final body = PdfStandardFont(PdfFontFamily.helvetica, 10);
  final violet = PdfColor(127, 61, 255);

  _Report() {
    doc.pageSettings.margins.all = 36;
    page = doc.pages.add();
    final c = page.getClientSize();
    w = c.width;
    bottom = c.height;
  }

  void ensure(double h) {
    if (y + h > bottom) {
      page = doc.pages.add();
      y = 0;
    }
  }

  void title(String t, String sub) {
    page.graphics.drawString(t, h1, bounds: Rect.fromLTWH(0, y, w, 28));
    page.graphics.drawString(sub, body,
        brush: PdfBrushes.gray, bounds: Rect.fromLTWH(0, y + 28, w, 14));
    y += 54;
  }

  void heading(String t) {
    ensure(60);
    y += 6;
    page.graphics.drawString(t, h2,
        brush: PdfSolidBrush(violet), bounds: Rect.fromLTWH(0, y, w, 18));
    y += 24;
  }

  void bullet(String t) {
    ensure(30);
    final r = PdfTextElement(text: '-  ${_pt(t)}', font: body)
        .draw(page: page, bounds: Rect.fromLTWH(0, y, w, 0));
    page = r!.page;
    y = r.bounds.bottom + 5;
  }

  void grid(List<String> head, List<List<String>> rows, {Set<int> right = const {}}) {
    final g = PdfGrid()
      ..columns.add(count: head.length)
      ..headers.add(1);
    g.style = PdfGridStyle(
      font: body,
      cellPadding: PdfPaddings(left: 3, right: 3, top: 3, bottom: 3),
    );
    for (final (i, h) in head.indexed) {
      g.headers[0].cells[i].value = h;
      g.headers[0].cells[i].style.backgroundBrush =
          PdfSolidBrush(PdfColor(238, 229, 255));
      if (right.contains(i)) {
        g.headers[0].cells[i].stringFormat =
            PdfStringFormat(alignment: PdfTextAlignment.right);
      }
    }
    for (final row in rows) {
      final r = g.rows.add();
      for (final (i, v) in row.indexed) {
        r.cells[i].value = _pt(v);
        if (right.contains(i)) {
          r.cells[i].stringFormat =
              PdfStringFormat(alignment: PdfTextAlignment.right);
        }
      }
    }
    ensure(50);
    final res = g.draw(page: page, bounds: Rect.fromLTWH(0, y, w, 0));
    page = res!.page;
    y = res.bounds.bottom + 14;
  }

  /// Horizontal bar rows: label, value, text shown at the right.
  void bars(List<(String, double, String)> rows, PdfColor color) {
    final max = rows.fold(0.0, (a, r) => r.$2 > a ? r.$2 : a);
    for (final r in rows) {
      ensure(20);
      page.graphics.drawString(_pt(r.$1), body,
          bounds: Rect.fromLTWH(0, y, 140, 14));
      final bw = max == 0 ? 0.0 : (w - 140 - 100) * r.$2 / max;
      page.graphics.drawRectangle(
          brush: PdfSolidBrush(color), bounds: Rect.fromLTWH(145, y + 2, bw < 1 ? 1 : bw, 9));
      page.graphics.drawString(_pt(r.$3), body,
          format: PdfStringFormat(alignment: PdfTextAlignment.right),
          bounds: Rect.fromLTWH(w - 95, y, 95, 14));
      y += 18;
    }
    y += 10;
  }
}

Future<Uint8List> buildReportPdf(List<Txn> txns, String period) async {
  final a = Analysis.of(txns);
  final r = _Report();
  final red = PdfColor(253, 60, 74);

  r.title('Financial analysis report',
      '$period   |   generated ${_d(DateTime.now())}   |   ${a.txns.length} transactions');

  r.heading('Summary');
  r.grid(['Measure', 'Value'], [
    ['Total income', _rs(a.income)],
    ['Total spent', _rs(a.expense)],
    [a.net >= 0 ? 'Saved' : 'Overspent', _rs(a.net.abs())],
    ['Savings rate', '${a.rate.round()}%'],
    ['Average spend per day', _rs(a.avgDaily.roundToDouble())],
    ['Transactions', '${a.txns.length}'],
  ], right: {1});

  r.heading('Insights');
  for (final i in a.insights) {
    r.bullet(i);
  }

  if (a.monthly.length > 1) {
    r.heading('Month by month');
    r.grid(['Month', 'Income', 'Expense', 'Net', 'Savings'], [
      for (final m in a.monthly)
        [
          m.$1,
          _rs(m.$2),
          _rs(m.$3),
          _rs(m.$2 - m.$3),
          m.$2 > 0 ? '${((m.$2 - m.$3) / m.$2 * 100).round()}%' : '-',
        ]
    ], right: {1, 2, 3, 4});
    r.bars([for (final m in a.monthly) ('${m.$1} spent', m.$3, _rs(m.$3))], red);
  }

  if (a.cats.isNotEmpty) {
    r.heading('Spending by category');
    r.bars([
      for (final c in a.cats)
        (c.key.name, c.value,
            '${_rs(c.value)} (${(c.value / a.expense * 100).round()}%)')
    ], r.violet);
  }

  if (a.merchants.isNotEmpty) {
    r.heading('Top merchants');
    r.bars([
      for (final m in a.merchants.take(10))
        ('${m.$1} (${m.$2}x)', m.$3, _rs(m.$3))
    ], PdfColor(255, 138, 61));
  }

  r.heading('Spending by weekday');
  r.bars([
    for (var i = 0; i < 7; i++) (weekdayNames[i], a.weekday[i], _rs(a.weekday[i]))
  ], PdfColor(20, 184, 166));

  r.heading('Payment methods');
  r.grid(['Method', 'Transactions', 'Amount'], [
    for (final e in a.modes.entries) [e.key, '${e.value.$1}', _rs(e.value.$2)]
  ], right: {1, 2});

  if (a.topExp.isNotEmpty) {
    r.heading('Biggest expenses');
    r.grid(['Date', 'Merchant', 'Category', 'Amount'], [
      for (final t in a.topExp.take(10))
        [_d(t.date), t.merchant, t.category.name, _rs(t.amount)]
    ], right: {3});
  }
  if (a.topInc.isNotEmpty) {
    r.heading('Biggest income');
    r.grid(['Date', 'Source', 'Category', 'Amount'], [
      for (final t in a.topInc.take(10))
        [_d(t.date), t.merchant, t.category.name, _rs(t.amount)]
    ], right: {3});
  }

  r.heading('All transactions');
  r.grid(['Date', 'Merchant', 'Category', 'Mode', 'Amount'], [
    for (final t in a.txns)
      [
        _d(t.date),
        t.merchant,
        t.category.name,
        t.mode,
        '${t.isIncome ? '+' : '-'} ${_rs(t.amount)}'
      ]
  ], right: {4});

  final bytes = Uint8List.fromList(await r.doc.save());
  r.doc.dispose();
  return bytes;
}
