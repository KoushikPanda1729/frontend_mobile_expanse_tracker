import 'package:expensetracker/data/ledger.dart';

const weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Plain-data version of the analysis, used for the downloadable report.
class Analysis {
  final List<Txn> txns; // oldest first
  final double income, expense;
  final int span; // days covered
  final List<MapEntry<Category, double>> cats;
  final List<(String, int, double)> merchants; // name, payments, total
  final List<Txn> topExp, topInc;
  final List<double> weekday; // spend per weekday, Mon..Sun
  final Map<String, (int, double)> modes; // mode -> (count, total)
  final List<(String, double, double)> monthly; // label, income, expense
  final List<String> insights;

  Analysis._(this.txns, this.income, this.expense, this.span, this.cats,
      this.merchants, this.topExp, this.topInc, this.weekday, this.modes,
      this.monthly, this.insights);

  double get net => income - expense;
  double get rate => income > 0 ? net / income * 100 : 0;
  double get avgDaily => expense / span;

  factory Analysis.of(List<Txn> txns) {
    final income = Ledger.income(txns), expense = Ledger.expense(txns);
    final span = txns.last.date.difference(txns.first.date).inDays + 1;
    final expenses = txns.where((t) => !t.isIncome).toList();

    final byMerchant = <String, List<Txn>>{};
    for (final t in expenses) {
      byMerchant.putIfAbsent(t.merchant, () => []).add(t);
    }
    final merchants = [
      for (final e in byMerchant.entries)
        (e.key, e.value.length, e.value.fold(0.0, (a, t) => a + t.amount))
    ]..sort((a, b) => b.$3.compareTo(a.$3));

    final topExp = [...expenses]..sort((a, b) => b.amount.compareTo(a.amount));
    final topInc = [...txns.where((t) => t.isIncome)]
      ..sort((a, b) => b.amount.compareTo(a.amount));

    final wd = List.filled(7, 0.0);
    for (final t in expenses) {
      wd[t.date.weekday - 1] += t.amount;
    }

    final modes = <String, (int, double)>{};
    for (final t in txns) {
      final m = modes[t.mode] ?? (0, 0.0);
      modes[t.mode] = (m.$1 + 1, m.$2 + t.amount);
    }

    final byMonth = <int, List<Txn>>{};
    for (final t in txns) {
      byMonth.putIfAbsent(Ledger.keyOf(t.date), () => []).add(t);
    }
    final months = byMonth.keys.toList()..sort();
    final monthly = [
      for (final k in months)
        ('${monthLabel(k)} ${k ~/ 100}', Ledger.income(byMonth[k]!),
            Ledger.expense(byMonth[k]!))
    ];

    final cats = Ledger.byCategory(txns);
    final small = expenses.where((t) => t.amount < 100).toList();
    final maxWd = wd.fold(0.0, (a, b) => a > b ? a : b);
    final net = income - expense;
    final insights = <String>[
      net >= 0
          ? 'You kept ${(income > 0 ? net / income * 100 : 0).round()}% of your income (${inr(net)} saved).'
          : 'You spent ${inr(-net)} more than you earned.',
      if (cats.isNotEmpty && expense > 0)
        '${cats.first.key.name} is your biggest spend: '
            '${(cats.first.value / expense * 100).round()}% (${inr(cats.first.value)}).',
      if (topExp.isNotEmpty)
        'Biggest expense: ${inr(topExp.first.amount)} to ${topExp.first.merchant} '
            'on ${shortDate(topExp.first.date)}.',
      if (merchants.isNotEmpty)
        'You paid ${merchants.first.$1} the most: ${inr(merchants.first.$3)} '
            'over ${merchants.first.$2} payment${merchants.first.$2 == 1 ? '' : 's'}.',
      if (small.isNotEmpty)
        '${small.length} small payments under ₹100 added up to '
            '${inr(small.fold(0.0, (a, t) => a + t.amount))}.',
      if (maxWd > 0)
        'You spend the most on ${weekdayNames[wd.indexOf(maxWd)]}s (${inr(maxWd)} in total).',
      if (monthly.length > 1)
        () {
          final cur = monthly.last.$3, prev = monthly[monthly.length - 2].$3;
          final ch = prev == 0 ? 0 : ((cur - prev) / prev * 100).round();
          return 'Spending in ${monthly.last.$1} is ${ch.abs()}% '
              '${ch > 0 ? 'higher' : 'lower'} than ${monthly[monthly.length - 2].$1}.';
        }(),
    ];

    return Analysis._(txns, income, expense, span, cats, merchants, topExp,
        topInc, wd, modes, monthly, insights);
  }
}
