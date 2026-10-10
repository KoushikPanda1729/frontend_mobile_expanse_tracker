import 'package:expensetracker/commons/components/sheets/app_sheets.dart';
import 'package:expensetracker/commons/components/button/app/solid_button_widget.dart';
import 'package:expensetracker/commons/constants/app_colors.dart';
import 'package:expensetracker/commons/text/app/views/custom_text_library.dart';
import 'package:expensetracker/data/analysis.dart';
import 'package:expensetracker/data/analytics.dart';
import 'package:expensetracker/data/ledger.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum _P { latest, previous, m3, m6, m12, all, custom }

/// Short analysis: the few numbers that matter. Full detail lives in the PDF report.
class AnalysisPage extends ConsumerStatefulWidget {
  const AnalysisPage({super.key});

  @override
  ConsumerState<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends ConsumerState<AnalysisPage> {
  _P _p = _P.all;
  DateTimeRange? _custom;

  static String _fmt(DateTime d) => '${shortDate(d)} ${d.year}';

  /// Presets are relative to the newest transaction, not today's date.
  DateTimeRange _range(Ledger l) {
    final first = l.all.first.date, last = l.all.last.date;
    DateTime start(int back) => DateTime(last.year, last.month - back, 1);
    DateTime end(int back) => DateTime(last.year, last.month - back + 1, 0);
    switch (_p) {
      case _P.latest:
        return DateTimeRange(start: start(0), end: end(0));
      case _P.previous:
        return DateTimeRange(start: start(1), end: end(1));
      case _P.m3:
        return DateTimeRange(start: start(2), end: last);
      case _P.m6:
        return DateTimeRange(start: start(5), end: last);
      case _P.m12:
        return DateTimeRange(start: start(11), end: last);
      case _P.custom:
        return _custom ?? DateTimeRange(start: first, end: last);
      case _P.all:
        return DateTimeRange(start: first, end: last);
    }
  }

  Future<void> _pickCustom(Ledger l) async {
    final lo = l.all.first.date, hi = l.all.last.date;
    final cur = _range(l);
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
        _p = _P.custom;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ledger = ref.watch(ledgerProvider).valueOrNull;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.dark100,
        centerTitle: true,
        title: const Text('Analysis',
            style: TextStyle(fontWeight: FontWeight.w700)),
        leading: BackButton(
            onPressed: () => context.canPop() ? context.pop() : context.go('/')),
      ),
      body: ledger == null
          ? const Center(child: CircularProgressIndicator())
          : _body(ledger),
    );
  }

  Widget _body(Ledger l) {
    if (l.all.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('No transactions yet', style: TextStyle(color: Colors.grey[600])),
            TextButton(
                onPressed: () => context.push('/import'),
                child: const Text('Import a statement')),
          ],
        ),
      );
    }
    final r = _range(l);
    final head = <Widget>[
      _periodChips(l),
      Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 16),
        child: Text('${_fmt(r.start)}  -  ${_fmt(r.end)}',
            style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ),
    ];
    Widget message(Widget child) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            ...head,
            Padding(padding: const EdgeInsets.only(top: 60), child: Center(child: child)),
          ],
        );

    // the numbers come from GET /analytics/summary
    final summary = ref.watch(summaryProvider((ymd(r.start), ymd(r.end))));
    return summary.when(
      loading: () => message(const CircularProgressIndicator()),
      error: (e, _) => message(Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Could not load the analysis\n$e', textAlign: TextAlign.center),
          TextButton(
            onPressed: () => ref.invalidate(summaryProvider),
            child: const Text('Retry'),
          ),
        ],
      )),
      data: (a) => a == null
          ? message(const Text('No transactions in this range'))
          : _content(head, a, r),
    );
  }

  Widget _content(List<Widget> head, Analysis a, DateTimeRange r) {
    // top 5 categories, the rest grouped as "Others"
    final top = a.cats.take(5).toList();
    final others = a.cats.skip(5).fold(0.0, (s, e) => s + e.value);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        ...head,
        _hero(a),
        const SizedBox(height: 28),
        _section(
          'Highlights',
          Column(children: [
            for (final i in a.insights.skip(1).take(3)) _insight(i),
          ]),
        ),
        if (top.isNotEmpty)
          _section(
            'Where your money went',
            Column(children: [
              for (final c in top)
                _rankRow(c.key.name,
                    '${(c.value / a.expense * 100).round()}% of spending',
                    inr(c.value), c.value / a.cats.first.value,
                    color: c.key.color),
              if (others > 0)
                _rankRow('Others', '', inr(others), others / a.cats.first.value,
                    color: AppColors.dark25),
            ]),
          ),
        if (a.merchants.isNotEmpty)
          _section(
            'Where you paid the most',
            Column(children: [
              for (final m in a.merchants.take(8))
                _rankRow(m.$1, '${m.$2} payment${m.$2 == 1 ? '' : 's'}',
                    inr(m.$3), m.$3 / a.merchants.first.$3),
            ]),
          ),
        if (a.monthly.length > 1)
          _section('Month by month', _monthlyBars(a.monthly)),
        _balanceTrend(r),
        SolidButtonWidget(
          label: 'Download full report',
          onPressed: () => context.push('/export'),
        ),
      ],
    );
  }

  // ---------- pieces ----------

  /// Running balance (GET /analytics/balance-trend).
  Widget _balanceTrend(DateTimeRange r) {
    final trend = ref.watch(balanceTrendProvider((ymd(r.start), ymd(r.end))));
    return trend.maybeWhen(
      data: (pts) {
        if (pts.length < 2) return const SizedBox.shrink();
        final lo = pts.map((p) => p.$2).reduce((a, b) => a < b ? a : b);
        final hi = pts.map((p) => p.$2).reduce((a, b) => a > b ? a : b);
        final pad = (hi - lo) * 0.1 + 1;
        return _section(
          'Balance trend',
          SizedBox(
            height: 170,
            child: LineChart(
              LineChartData(
                minY: lo - pad,
                maxY: hi + pad,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: const FlTitlesData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: AppColors.violet100,
                    getTooltipItems: (spots) => [
                      for (final s in spots)
                        LineTooltipItem(
                          '${shortDate(pts[s.x.toInt()].$1)}\n${inr(s.y)}',
                          const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w600),
                        )
                    ],
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < pts.length; i++)
                        FlSpot(i.toDouble(), pts[i].$2)
                    ],
                    isCurved: true,
                    color: AppColors.violet100,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.violet100.withOpacity(0.12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _periodChips(Ledger l) {
    Widget chip(String label, _P p, {bool custom = false}) {
      final sel = _p == p;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          avatar: custom
              ? Icon(Icons.date_range,
                  size: 16, color: sel ? Colors.white : AppColors.dark50)
              : null,
          label: Text(label),
          selected: sel,
          onSelected: (_) => custom ? _pickCustom(l) : setState(() => _p = p),
          selectedColor: AppColors.violet100,
          labelStyle: TextStyle(color: sel ? Colors.white : AppColors.dark50),
          showCheckmark: false,
          backgroundColor: AppColors.violet20,
          side: BorderSide.none,
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        chip('Latest month', _P.latest),
        chip('Previous month', _P.previous),
        chip('3 months', _P.m3),
        chip('6 months', _P.m6),
        chip('12 months', _P.m12),
        chip('All time', _P.all),
        chip('Custom', _P.custom, custom: true),
      ]),
    );
  }

  /// One card: what you saved, with income and spend underneath.
  Widget _hero(Analysis a) {
    Widget pill(String label, double v, IconData icon) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle),
                  child: Icon(icon,
                      size: 16,
                      color: label == 'Income'
                          ? AppColors.green100
                          : AppColors.red100),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(inr(v),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.violet80, AppColors.violet100],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(a.net >= 0 ? 'You saved' : 'You overspent',
                  style: const TextStyle(color: Colors.white70, fontSize: 14)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${a.rate.round()}% of income',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(inr(a.net.abs()),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              pill('Income', a.income, Icons.south_west),
              const SizedBox(width: 12),
              pill('Spent', a.expense, Icons.north_east),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '${inr(a.avgDaily.roundToDouble())} average per day  ·  ${a.count} transactions',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Title3(text: title), const SizedBox(height: 14), child],
        ),
      );

  Widget _insight(String text) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lightbulb_outline,
                size: 20, color: AppColors.violet100),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
          ],
        ),
      );

  Widget _rankRow(String title, String sub, String amount, double share,
      {Color color = AppColors.violet100}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (sub.isNotEmpty)
                      Text(sub,
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 12)),
                  ],
                ),
              ),
              Text(amount, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: share.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend(Color c, String t) => Row(children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(t, style: const TextStyle(fontSize: 12)),
      ]);

  Widget _monthlyBars(List<(String, double, double)> m) {
    final w = m.length > 6 ? 7.0 : 14.0;
    return Column(
      children: [
        Row(children: [
          _legend(AppColors.green100, 'Income'),
          const SizedBox(width: 16),
          _legend(AppColors.red100, 'Spent'),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: 170,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  tooltipBgColor: AppColors.violet100,
                  getTooltipItem: (g, gi, rod, ri) => BarTooltipItem(
                    inr(rod.toY),
                    const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                leftTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (v, meta) => Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(m[v.toInt()].$1.substring(0, 3),
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 11)),
                    ),
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < m.length; i++)
                  BarChartGroupData(x: i, barsSpace: 3, barRods: [
                    BarChartRodData(
                      toY: m[i].$2,
                      color: AppColors.green100,
                      width: w,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    BarChartRodData(
                      toY: m[i].$3,
                      color: AppColors.red100,
                      width: w,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ]),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
