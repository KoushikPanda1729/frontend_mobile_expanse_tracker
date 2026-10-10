import 'package:expensetracker/commons/components/notification_bar/notification_bar.dart';
import 'package:expensetracker/commons/components/month_pill/month_pill.dart';
import 'package:expensetracker/commons/components/transaction_card/app/transaction_card.dart';
import 'package:expensetracker/commons/constants/app_colors.dart';
import 'package:expensetracker/commons/text/app/views/custom_text_library.dart';
import 'package:expensetracker/data/analysis.dart' show weekdayNames;
import 'package:expensetracker/data/analytics.dart';
import 'package:expensetracker/pages/transaction/transaction_sheet.dart';
import 'package:expensetracker/data/ledger.dart';
import 'package:expensetracker/data/reminder.dart';
import 'package:expensetracker/data/review.dart';
import 'package:expensetracker/data/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String selectedFilter = 'Day';
  int _key = 0; // period shown (month, or a range: see Ledger.inMonth)

  /// Day view only makes sense inside one month; a range shows months instead.
  String get _filter => (_key <= 0 && selectedFilter == 'Day') ? 'Month' : selectedFilter;
  DateTime? _sel; // day picked in the day-wise chart

  void toggleFilter(String newFilter) {
    setState(() {
      selectedFilter = newFilter;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ledger = ref.watch(ledgerProvider);
    return Scaffold(
      body: SafeArea(
        child: ledger.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Could not load data\n$e', textAlign: TextAlign.center),
                TextButton(
                  onPressed: () => ref.invalidate(ledgerProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: _buildBody,
        ),
      ),
    );
  }

  Widget _buildBody(Ledger ledger) {
    final keys = ledger.monthKeys;
    final key = ref.watch(monthProvider) ?? keys.last;
    _key = key;
    final txns = ledger.inMonth(key);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: NotificationBar(
              isPrifileVisible: true,
              isFiltered: false,
              child: Row(
                children: [
                  const MonthPill(),
                ],
              ),
              onTap: () {
                context.push('/notifications');
              }),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildBalanceCard(
                    key: key,
                    balance: _balance(ledger, key),
                    income: Ledger.income(txns),
                    expense: Ledger.expense(txns),
                  ),
                  _nudge(ledger),
                  if (ledger.all.isNotEmpty) _reviewBanner(),
                  const SizedBox(height: 28),
                  if (ledger.all.isEmpty)
                    _emptyState()
                  else ...[
                    buildDayWise(ledger, txns),
                    const SizedBox(height: 24),
                    buildCategoryPie(txns),
                    const SizedBox(height: 24),
                    buildRecentTransactions(context, ref, txns,
                        () => ref.read(tabProvider.notifier).state = 1),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Slim reminder under the balance card: statement due, or set up the month-end alarm.
  Widget _nudge(Ledger ledger) {
    final r = ref.watch(reminderProvider);
    final n = nudgeFor(ledger, r, DateTime.now());
    if (n == null) return const SizedBox.shrink();
    final due = n.kind == NudgeKind.due;
    final notifier = ref.read(reminderProvider.notifier);
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.violet100.withOpacity(0.25)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: const BoxDecoration(
                color: AppColors.violet20, shape: BoxShape.circle),
            child: Icon(
              due ? Icons.event_available_outlined : Icons.alarm_add_outlined,
              size: 20,
              color: AppColors.violet100,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(n.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 2),
                Text(n.sub,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              if (due) {
                context.push('/import');
                return;
              }
              final messenger = ScaffoldMessenger.of(context);
              final ok = await notifier.enable();
              messenger.showSnackBar(SnackBar(
                content: Text(ok
                    ? 'Alarm set for the last day of every month, '
                        '${ref.read(reminderProvider).hour.toString().padLeft(2, '0')}:'
                        '${ref.read(reminderProvider).minute.toString().padLeft(2, '0')}'
                    : 'Allow notifications in Settings to get the alarm'),
              ));
            },
            child: Text(due ? 'Import' : 'Turn on',
                style: const TextStyle(
                    color: AppColors.violet100, fontWeight: FontWeight.w700)),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: due ? 'Remind me tomorrow' : 'Not now',
            icon: Icon(Icons.close, size: 18, color: Colors.grey[500]),
            onPressed: due ? notifier.snoozeToday : notifier.dismissSetup,
          ),
        ],
      ),
    );
  }

  /// Balance at the end of the chosen month (or the newest transaction for a range), from GET /analytics/balance.
  /// It is added up here until the server answers.
  double _balance(Ledger l, int key) {
    final local = l.balanceAtEnd(key);
    if (l.all.isEmpty) return local;
    final end = key > 0 ? DateTime(key ~/ 100, key % 100 + 1, 0) : l.all.last.date;
    return ref.watch(balanceProvider(ymd(end))).valueOrNull ?? local;
  }

  /// "N payments to check": shown when the review has something the app cannot explain.
  Widget _reviewBanner() {
    final r = ref.watch(reviewProvider).valueOrNull;
    if (r == null || r.count == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Material(
        color: AppColors.yellow100.withOpacity(0.18),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/review'),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(Icons.search, color: AppColors.violet100),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${r.count} payment${r.count == 1 ? '' : 's'} to check',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text('${inr(r.unknownSent)} went to people you have not labelled',
                          style: TextStyle(color: Colors.grey[700], fontSize: 12.5)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.violet100),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// A new account has no data yet: offer the two ways to add some.
  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.violet20.withOpacity(0.5),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Icon(Icons.account_balance_wallet_outlined,
              size: 44, color: AppColors.violet100),
          const SizedBox(height: 12),
          const Text('No transactions yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('Import your bank statement or add a transaction by hand.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700], height: 1.4)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.violet100,
                    minimumSize: const Size.fromHeight(48),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: () => context.push('/import'),
                  icon: const Icon(Icons.upload_file, size: 18),
                  label: const Text('Import PDF', maxLines: 1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.violet100,
                    side: const BorderSide(color: AppColors.violet100),
                    minimumSize: const Size.fromHeight(48),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: () => context.push('/expenses'),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add entry', maxLines: 1),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildBalanceCard({
    required int key,
    required double balance,
    required double income,
    required double expense,
  }) {
    Widget pill(String label, double v, IconData icon, String route) {
      return Expanded(
        child: GestureDetector(
          onTap: () => context.push(route),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                      const SizedBox(height: 2),
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
        ),
      );
    }

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
        boxShadow: [
          BoxShadow(
            color: AppColors.violet100.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Balance · ${monthLabel(key)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 14)),
              GestureDetector(
                onTap: () => ref.read(hideBalanceProvider.notifier).state =
                    !ref.read(hideBalanceProvider),
                child: Icon(
                  ref.watch(hideBalanceProvider)
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.white70,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(ref.watch(hideBalanceProvider) ? '₹ ••••••' : inr(balance),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              pill('Income', income, Icons.south_west, '/income'),
              const SizedBox(width: 12),
              pill('Expenses', expense, Icons.north_east, '/expenses'),
            ],
          ),

        ],
      ),
    );
  }

  /// Spend Frequency line chart.
  /// Day = spend per day of the month (tap a day for its transactions),
  /// Week = weekly totals, Month = monthly totals.
  Widget buildDayWise(Ledger ledger, List<Txn> month) {
    final ref0 = month.last.date;
    final lastDay = DateTime(ref0.year, ref0.month + 1, 0).day;
    final sel = (_sel != null &&
            _sel!.year == ref0.year &&
            _sel!.month == ref0.month)
        ? _sel!
        : ref0;
    final isDay = _filter == 'Day';

    // x -> spend, x -> axis label, x -> tooltip title
    final y = <int, double>{};
    final labels = <int, String>{};
    final titles = <int, String>{};
    double minX, maxX;
    // chart numbers come from GET /analytics/series; until they load they are added up here
    if (isDay) {
      final srv = ref
          .watch(seriesProvider((
            'day',
            ymd(DateTime(ref0.year, ref0.month, 1)),
            ymd(DateTime(ref0.year, ref0.month, lastDay)),
          )))
          .valueOrNull;
      final spend = <int, double>{};
      if (srv != null) {
        for (final p in srv) {
          spend[p.$1.day] = p.$2;
        }
      } else {
        for (final t in month.where((t) => !t.isIncome)) {
          spend[t.date.day] = (spend[t.date.day] ?? 0) + t.amount;
        }
      }
      for (var d = 1; d <= lastDay; d++) {
        y[d] = spend[d] ?? 0;
        labels[d] = (d == 1 || d % 5 == 0) ? '$d' : '';
        final dt = DateTime(ref0.year, ref0.month, d);
        titles[d] = '${weekdayNames[dt.weekday - 1]} ${shortDate(dt)}';
      }
      minX = 1;
      maxX = lastDay.toDouble();
    } else if (_filter == 'Week') {
      final srv = ref.watch(seriesProvider(('week', null, null))).valueOrNull;
      final useSrv = srv != null && srv.isNotEmpty;
      final first = useSrv ? srv.first.$1 : ledger.all.first.date;
      final last = useSrv ? srv.last.$1 : ledger.all.last.date;
      if (useSrv) {
        for (final p in srv) {
          final i = p.$1.difference(first).inDays ~/ 7;
          y[i] = (y[i] ?? 0) + p.$2;
        }
      } else {
        for (final t in ledger.all.where((t) => !t.isIncome)) {
          final i = t.date.difference(first).inDays ~/ 7;
          y[i] = (y[i] ?? 0) + t.amount;
        }
      }
      final n = last.difference(first).inDays ~/ 7;
      for (var i = 0; i <= n; i++) {
        y[i] = y[i] ?? 0;
        labels[i] = i % 2 == 0 ? 'W${i + 1}' : '';
        titles[i] = 'Week ${i + 1}';
      }
      minX = 0;
      maxX = (n < 1 ? 1 : n).toDouble();
    } else {
      final srv = ref.watch(seriesProvider(('month', null, null))).valueOrNull;
      final useSrv = srv != null && srv.isNotEmpty;
      final keys = useSrv
          ? [for (final p in srv) p.$1.year * 100 + p.$1.month]
          : ledger.monthKeys;
      for (var i = 0; i < keys.length; i++) {
        y[i] = useSrv ? srv[i].$2 : Ledger.expense(ledger.inMonth(keys[i]));
        labels[i] = monthLabel(keys[i]).substring(0, 3);
        titles[i] = '${monthLabel(keys[i])} ${keys[i] ~/ 100}';
      }
      minX = 0;
      maxX = (keys.length < 2 ? 1 : keys.length - 1).toDouble();
    }
    final spots = [
      for (final e in y.entries) FlSpot(e.key.toDouble(), e.value)
    ]..sort((a, b) => a.x.compareTo(b.x));

    final dayTx = month.where((t) => t.date.day == sel.day).toList();
    final spent = Ledger.expense(dayTx), got = Ledger.income(dayTx);

    void go(int delta) {
      final d = sel.day + delta;
      if (d >= 1 && d <= lastDay) {
        setState(() => _sel = DateTime(ref0.year, ref0.month, d));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Title3(text: "Spend Frequency"),
            GestureDetector(
              onTap: () => context.push('/analysis'),
              child: const Row(
                children: [
                  Text('Full analysis',
                      style: TextStyle(
                          color: AppColors.violet100,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                  Icon(Icons.chevron_right,
                      size: 18, color: AppColors.violet100),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 190,
          child: LineChart(
            LineChartData(
              minX: minX,
              maxX: maxX,
              minY: 0,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              lineTouchData: LineTouchData(
                touchCallback: (event, resp) {
                  final pts = resp?.lineBarSpots;
                  if (isDay &&
                      event is FlTapUpEvent &&
                      pts != null &&
                      pts.isNotEmpty) {
                    setState(() => _sel = DateTime(
                        ref0.year, ref0.month, pts.first.x.round()));
                  }
                },
                touchTooltipData: LineTouchTooltipData(
                  tooltipBgColor: AppColors.violet100,
                  getTooltipItems: (pts) => [
                    for (final p in pts)
                      LineTooltipItem(
                        '${titles[p.x.round()] ?? ''}\n${inr(p.y)}',
                        const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                  ],
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
                    reservedSize: 24,
                    interval: 1,
                    getTitlesWidget: (v, meta) => Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        v == v.roundToDouble() ? (labels[v.toInt()] ?? '') : '',
                        style: const TextStyle(
                            color: AppColors.dark25, fontSize: 11),
                      ),
                    ),
                  ),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.25,
                  preventCurveOverShooting: true,
                  color: AppColors.violet100,
                  barWidth: 1.5,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: isDay,
                    checkToShowDot: (s, b) => s.x == sel.day.toDouble(),
                    getDotPainter: (s, p, b, i) => FlDotCirclePainter(
                      radius: 5,
                      color: AppColors.violet100,
                      strokeWidth: 3,
                      strokeColor: Colors.white,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        AppColors.violet100.withOpacity(0.0),
                        AppColors.violet100.withOpacity(0.3),
                      ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            buildTimeFilterChip('Day'),
            buildTimeFilterChip('Week'),
            buildTimeFilterChip('Month'),
          ],
        ),
        if (isDay) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              GestureDetector(
                onTap: () => go(-1),
                child: const Icon(Icons.chevron_left, color: AppColors.violet100),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '${weekdayNames[sel.weekday - 1]}, ${shortDate(sel)} ${sel.year}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dayTx.isEmpty
                          ? 'No transactions'
                          : 'Spent ${inr(spent)}  ·  Received ${inr(got)}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => go(1),
                child:
                    const Icon(Icons.chevron_right, color: AppColors.violet100),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final t in dayTx) ...[
            TransactionCard(
              icon: t.category.icon,
              iconColor: t.category.color,
              isIncome: t.isIncome,
              title: t.merchant,
              description: t.subtitle,
              amount: '${t.isIncome ? '+' : '-'} ${inr(t.amount)}',
              onTap: () => showTransactionSheet(context, ref, t),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }

  Widget buildTimeFilterChip(String label) {
    bool isSelected = _filter == label;

    return GestureDetector(
      onTap: () {
        toggleFilter(label);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.violet20
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Body3(
          text: label,
          color: isSelected ? AppColors.violet100 : AppColors.dark25,
        ),
      ),
    );
  }
}

Widget buildRecentTransactions(BuildContext context, WidgetRef ref, List<Txn> month, VoidCallback onSeeAll) {
  final recent = month.reversed.take(6).toList();
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      NotificationBar(
        isPrifileVisible: false,
        isTrailingIcon: false,
        isBottonRequired: true,
        title: "Recent Transaction",
        onTap: onSeeAll,
      ),
      const SizedBox(height: 16),
      for (final t in recent) ...[
        TransactionCard(
          icon: t.category.icon,
          iconColor: t.category.color,
          isIncome: t.isIncome,
          title: t.merchant,
          description: t.subtitle,
          time: shortDate(t.date),
          amount: '${t.isIncome ? '+' : '-'} ${inr(t.amount)}',
          onTap: () => showTransactionSheet(context, ref, t),
        ),
        const SizedBox(height: 8),
      ],
    ],
  );
}

Widget buildCategoryPie(List<Txn> month) {
  final cats = Ledger.byCategory(month);
  final total = cats.fold(0.0, (a, e) => a + e.value);
  if (total == 0) return const SizedBox.shrink();
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Title3(text: "Spending by Category"),
      const SizedBox(height: 16),
      SizedBox(
        height: 200,
        child: Stack(
          alignment: Alignment.center,
          children: [
            PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 70,
                sections: [
                  for (final e in cats)
                    PieChartSectionData(
                      value: e.value,
                      color: e.key.color,
                      radius: 20,
                      showTitle: false,
                    ),
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Total spent',
                    style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 2),
                Text(inr(total),
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      for (final e in cats)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: e.key.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SvgPicture.asset(
                  e.key.icon,
                  width: 20,
                  height: 20,
                  colorFilter: ColorFilter.mode(e.key.color, BlendMode.srcIn),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(e.key.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        Text(inr(e.value),
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: e.value / total,
                              minHeight: 6,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation(e.key.color),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text('${(e.value / total * 100).round()}%',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
    ],
  );
}
