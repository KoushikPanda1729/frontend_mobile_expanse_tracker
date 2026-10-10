import 'package:expensetracker/commons/components/sheets/app_sheets.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:expensetracker/commons/components/button/app/solid_button_widget.dart';
import 'package:expensetracker/commons/constants/app_colors.dart';
import 'package:expensetracker/commons/text/app/views/custom_text_library.dart';
import 'package:expensetracker/data/exporter.dart';
import 'package:expensetracker/data/ledger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum _Preset { all, latest, previous, last3, custom }

enum _Fmt { csv, pdf, report }

class ExportPage extends ConsumerStatefulWidget {
  const ExportPage({super.key});

  @override
  ConsumerState<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends ConsumerState<ExportPage> {
  _Preset _preset = _Preset.all;
  DateTimeRange? _custom;
  String? _type; // Income | Expense | null = both
  final Set<String> _cats = {};
  _Fmt _format = _Fmt.report; // analysis report is the default
  bool _busy = false;

  static String _fmt(DateTime d) => '${shortDate(d)} ${d.year}';

  DateTimeRange _range(Ledger l) {
    final first = l.all.first.date, last = l.all.last.date;
    DateTime monthStart(int back) => DateTime(last.year, last.month - back, 1);
    DateTime monthEnd(int back) => DateTime(last.year, last.month - back + 1, 0);
    switch (_preset) {
      case _Preset.latest:
        return DateTimeRange(start: monthStart(0), end: monthEnd(0));
      case _Preset.previous:
        return DateTimeRange(start: monthStart(1), end: monthEnd(1));
      case _Preset.last3:
        return DateTimeRange(start: monthStart(2), end: last);
      case _Preset.custom:
        return _custom ?? DateTimeRange(start: first, end: last);
      case _Preset.all:
        return DateTimeRange(start: first, end: last);
    }
  }

  List<Txn> _selected(Ledger l, DateTimeRange r) => [
        for (final t in l.all)
          if (!t.date.isBefore(r.start) &&
              !t.date.isAfter(r.end) &&
              (_type == null || t.isIncome == (_type == 'Income')) &&
              (_cats.isEmpty || _cats.contains(t.category.name)))
            t
      ];

  Future<void> _pickCustom(Ledger l) async {
    final lo = l.all.first.date, hi = l.all.last.date;
    final cur = _custom ?? _range(l);
    final r = await pickRangeSheet(
      context,
      first: lo,
      last: hi,
      initial: DateTimeRange(
        start: cur.start.isBefore(lo) ? lo : cur.start,
        end: cur.end.isAfter(hi) ? hi : cur.end,
      ),
    );
    if (r != null) {
      setState(() {
        _custom = r;
        _preset = _Preset.custom;
      });
    }
  }

  Future<void> _export(List<Txn> txns, DateTimeRange r) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      String iso(DateTime d) => d.toIso8601String().substring(0, 10);
      final base = 'statement_${iso(r.start)}_to_${iso(r.end)}';
      final period = '${_fmt(r.start)} - ${_fmt(r.end)}';
      if (_format == _Fmt.report) {
        await shareFile(await buildReportPdf(txns, period),
            'analysis_report_${iso(r.start)}_to_${iso(r.end)}.pdf',
            'application/pdf');
      } else if (_format == _Fmt.pdf) {
        await shareFile(
            await buildPdf(txns, period), '$base.pdf', 'application/pdf');
      } else {
        await shareFile(Uint8List.fromList(utf8.encode(buildCsv(txns))),
            '$base.csv', 'text/csv');
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(ledgerProvider).valueOrNull;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.dark100,
        centerTitle: true,
        title: const Text('Export Data',
            style: TextStyle(fontWeight: FontWeight.w700)),
        leading: BackButton(
            onPressed: () => context.canPop() ? context.pop() : context.go('/')),
      ),
      body: l == null || l.all.isEmpty
          ? const Center(child: Text('No transactions to export'))
          : _body(l),
    );
  }

  Widget _body(Ledger l) {
    final r = _range(l);
    final txns = _selected(l, r);
    final cats = {for (final t in l.all) t.category.name: t.category}.values.toList();

    Widget chip(String label, bool sel, VoidCallback onTap) => ChoiceChip(
          label: Text(label),
          selected: sel,
          onSelected: (_) => onTap(),
          selectedColor: AppColors.violet100,
          labelStyle: TextStyle(color: sel ? Colors.white : AppColors.dark50),
          showCheckmark: false,
          backgroundColor: AppColors.violet20,
          side: BorderSide.none,
        );

    Widget label(String t) => Padding(
          padding: const EdgeInsets.only(bottom: 10, top: 22),
          child: Title3(text: t),
        );

    Widget formatCard(String title, String sub, IconData icon, _Fmt f) {
      final sel = _format == f;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: GestureDetector(
          onTap: () => setState(() => _format = f),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: sel ? AppColors.violet20 : Colors.transparent,
              border: Border.all(
                  color: sel ? AppColors.violet100 : AppColors.light20,
                  width: sel ? 1.5 : 1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(icon, color: sel ? AppColors.violet100 : AppColors.dark25),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(sub,
                          style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              label('Date range'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  chip('All time', _preset == _Preset.all,
                      () => setState(() => _preset = _Preset.all)),
                  chip('Latest month', _preset == _Preset.latest,
                      () => setState(() => _preset = _Preset.latest)),
                  chip('Previous month', _preset == _Preset.previous,
                      () => setState(() => _preset = _Preset.previous)),
                  chip('Last 3 months', _preset == _Preset.last3,
                      () => setState(() => _preset = _Preset.last3)),
                  chip('Custom', _preset == _Preset.custom, () => _pickCustom(l)),
                ],
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => _pickCustom(l),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.light20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.date_range,
                          size: 20, color: AppColors.violet100),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('${_fmt(r.start)}  →  ${_fmt(r.end)}',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      const Icon(Icons.edit_calendar_outlined,
                          size: 18, color: AppColors.dark25),
                    ],
                  ),
                ),
              ),
              label('Transaction type'),
              Wrap(
                spacing: 8,
                children: [
                  chip('All', _type == null, () => setState(() => _type = null)),
                  chip('Income', _type == 'Income',
                      () => setState(() => _type = 'Income')),
                  chip('Expense', _type == 'Expense',
                      () => setState(() => _type = 'Expense')),
                ],
              ),
              label('Categories'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  chip('All', _cats.isEmpty, () => setState(_cats.clear)),
                  for (final c in cats)
                    chip(
                      c.name,
                      _cats.contains(c.name),
                      () => setState(() => _cats.contains(c.name)
                          ? _cats.remove(c.name)
                          : _cats.add(c.name)),
                    ),
                ],
              ),
              label('Format'),
              formatCard('Full analysis report', 'PDF with insights, charts and tables, plus every transaction',
                  Icons.insights, _Fmt.report),
              formatCard('Transactions (CSV)', 'Rows for Excel or Google Sheets',
                  Icons.table_chart_outlined, _Fmt.csv),
              formatCard('Transactions (PDF)', 'Simple printable list',
                  Icons.picture_as_pdf_outlined, _Fmt.pdf),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.violet20,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${txns.length} transactions will be exported',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.violet100)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text('Income\n${inr(Ledger.income(txns))}',
                              style: const TextStyle(
                                  color: AppColors.green100,
                                  fontWeight: FontWeight.w600)),
                        ),
                        Expanded(
                          child: Text('Expense\n${inr(Ledger.expense(txns))}',
                              style: const TextStyle(
                                  color: AppColors.red100,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_format == _Fmt.csv)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: txns.isEmpty
                        ? null
                        : () {
                            Clipboard.setData(ClipboardData(text: buildCsv(txns)));
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('${txns.length} rows copied as CSV')));
                          },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy CSV to clipboard'),
                  ),
                ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SolidButtonWidget(
              label: _busy
                  ? 'Preparing...'
                  : (_format == _Fmt.report ? 'Download report' : 'Download ${_format == _Fmt.pdf ? 'PDF' : 'CSV'}'),
              onPressed: txns.isEmpty || _busy ? null : () => _export(txns, r),
            ),
          ),
        ),
      ],
    );
  }
}
