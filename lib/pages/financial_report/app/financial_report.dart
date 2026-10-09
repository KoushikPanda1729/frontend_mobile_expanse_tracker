import 'package:expensetracker/commons/constants/app_colors.dart';
import 'package:expensetracker/data/ledger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:expensetracker/pages/financial_report/app/spending_page.dart';
import 'package:expensetracker/pages/financial_report/app/quote_page.dart';

class FinancialReport extends ConsumerStatefulWidget {
  const FinancialReport({super.key});

  @override
  ConsumerState<FinancialReport> createState() => _FinancialReportState();
}

class _FinancialReportState extends ConsumerState<FinancialReport> {
  late PageController _pageController;
  int _currentIndex = 0;

  List<Widget> _pages = const [];

  List<Widget> _buildPages() {
    final ledger = ref.watch(ledgerProvider).valueOrNull;
    if (ledger == null) return const [QuotePage()];
    final key = ref.watch(monthProvider) ?? ledger.monthKeys.last;
    final txns = ledger.inMonth(key);
    final keys = ledger.monthKeys;
    final at = keys.indexOf(key);
    final prev = at > 0 ? ledger.inMonth(keys[at - 1]) : const <Txn>[];
    final period = '${monthLabel(key)} ${key ~/ 100}';
    String change(double cur, double before, String prevName) {
      if (before == 0) return '';
      final p = ((cur - before) / before * 100).round();
      if (p == 0) return 'Same as $prevName';
      return '${p.abs()}% ${p > 0 ? 'more' : 'less'} than $prevName';
    }

    List<ReportItem> top(List<MapEntry<Category, double>> l, double total) => [
          for (final e in l.take(3))
            ReportItem(e.key.icon, e.key.name, inr(e.value.roundToDouble()),
                total == 0 ? 0 : e.value / total)
        ];
    final spend = Ledger.byCategory(txns);
    final earn = Ledger.byCategory(txns, income: true);
    final budgets = ref.watch(budgetsProvider);
    final spentBy = {for (final e in spend) e.key.name: e.value};
    final over = [
      for (final b in budgets.entries)
        if ((spentBy[b.key] ?? 0) > b.value) categoryByName(b.key)
    ];
    // budget slide rows: exceeded ones, else the three closest to their limit
    final byUse = budgets.entries.toList()
      ..sort((a, b) => ((spentBy[b.key] ?? 0) / b.value)
          .compareTo((spentBy[a.key] ?? 0) / a.value));
    final budgetItems = [
      for (final b in (over.isEmpty ? byUse.take(3) : byUse.take(over.length)))
        ReportItem(
          categoryByName(b.key).icon,
          b.key,
          '',
          ((spentBy[b.key] ?? 0) / b.value).clamp(0.0, 1.0),
          trailing: (spentBy[b.key] ?? 0) > b.value
              ? 'Over by ${inr((spentBy[b.key]! - b.value).roundToDouble())}'
              : '${((spentBy[b.key] ?? 0) / b.value * 100).round()}% used',
          barColor: (spentBy[b.key] ?? 0) > b.value
              ? AppColors.red100
              : AppColors.violet100,
        )
    ];
    String rupees(double v) => inr(v.roundToDouble());
    return [
      SpendingEarningPage(
        backgroundColor: AppColors.red100,
        totalSpendAndEarned: rupees(Ledger.expense(txns)),
        title: "You Spend",
        period: period,
        subtitle: at > 0
            ? change(Ledger.expense(txns), Ledger.expense(prev),
                monthLabel(keys[at - 1]))
            : '${txns.where((t) => !t.isIncome).length} payments',
        items: top(spend, Ledger.expense(txns)),
        cardTitle: "Where it went",
        icons: [if (spend.isNotEmpty) spend.first.key.icon],
        categories: [if (spend.isNotEmpty) spend.first.key.name],
        maxEarnAndSpend: spend.isEmpty ? '₹0' : rupees(spend.first.value),
      ),
      SpendingEarningPage(
        backgroundColor: AppColors.green100,
        totalSpendAndEarned: rupees(Ledger.income(txns)),
        title: "You Earned",
        period: period,
        subtitle: at > 0
            ? change(Ledger.income(txns), Ledger.income(prev),
                monthLabel(keys[at - 1]))
            : '${txns.where((t) => t.isIncome).length} credits',
        items: top(earn, Ledger.income(txns)),
        cardTitle: "Where it came from",
        icons: [if (earn.isNotEmpty) earn.first.key.icon],
        categories: [if (earn.isNotEmpty) earn.first.key.name],
        maxEarnAndSpend: earn.isEmpty ? '₹0' : rupees(earn.first.value),
      ),
      SpendingEarningPage(
        backgroundColor: AppColors.violet100,
        totalSpendAndEarned: "",
        period: period,
        title: budgets.isEmpty
            ? "No budgets set"
            : over.isEmpty
                ? "All budgets on track"
                : "${over.length} of ${budgets.length} budgets exceeded",
        cardTitle: over.isEmpty ? "Closest to the limit" : "Over budget",
        icons: const [],
        categories: const [],
        maxEarnAndSpend: "",
        items: budgetItems,
        isBudget: true,
      ),
      SummaryPage(
        period: period,
        income: Ledger.income(txns),
        expense: Ledger.expense(txns),
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    // pages are built in build() from ledger state
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToNextPage() {
    if (_currentIndex < _pages.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToPreviousPage() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    _pages = _buildPages();
    return Scaffold(
      body: GestureDetector(
        onTapUp: (details) {
          double screenWidth = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < screenWidth / 2) {
            _goToPreviousPage();
          } else {
            _goToNextPage();
          }
        },
        child: Stack(
          children: [
            PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              children: _pages,
            ),
            Positioned(
              top: 70,
              right: 6,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Positioned(
              top: 60,
              left: 10,
              right: 10,
              child: Row(
                children: List.generate(_pages.length, (index) {
                  return Expanded(
                    child: Container(
                      width: MediaQuery.of(context).size.width /
                          (_pages.length * 1.5),
                      height: 3,
                      decoration: BoxDecoration(
                        color: index == _currentIndex
                            ? Colors.white
                            : Colors.white.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
