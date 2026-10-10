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
  final int count; // number of transactions

  Analysis._(this.txns, this.income, this.expense, this.span, this.cats,
      this.merchants, this.topExp, this.topInc, this.weekday, this.modes,
      this.monthly, this.insights, this.count);

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
    final insights = _insights(income, expense, cats, topExp, merchants, wd,
        monthly, small.length, small.fold(0.0, (a, t) => a + t.amount));

    return Analysis._(txns, income, expense, span, cats, merchants, topExp,
        topInc, wd, modes, monthly, insights, txns.length);
  }

  /// Same numbers from GET /analytics/summary (the server did the adding up).
  factory Analysis.fromSummary(Map<String, dynamic> j) {
    final income = (j['income'] as num).toDouble();
    final expense = (j['expense'] as num).toDouble();
    final range = j['range'] as Map<String, dynamic>;
    final span = range['from'] == null
        ? 1
        : DateTime.parse(range['to'] as String)
                .difference(DateTime.parse(range['from'] as String))
                .inDays +
            1;
    final cats = [
      for (final c in j['byCategory'] as List)
        MapEntry(categoryByName((c as Map<String, dynamic>)['category'] as String),
            (c['total'] as num).toDouble())
    ];
    final merchants = [
      for (final m in j['topMerchants'] as List)
        (
          (m as Map<String, dynamic>)['merchant'] as String,
          m['count'] as int,
          (m['total'] as num).toDouble()
        )
    ];
    final topExp = [
      for (final t in j['biggestExpenses'] as List)
        Txn(
          date: DateTime.parse((t as Map<String, dynamic>)['date'] as String),
          merchant: t['merchant'] as String,
          mode: '',
          category: categoryByName(t['category'] as String),
          amount: (t['amount'] as num).toDouble(),
          isIncome: false,
        )
    ];
    final wd = List.filled(7, 0.0);
    for (final w in j['byWeekday'] as List) {
      wd[((w as Map<String, dynamic>)['weekday'] as int) - 1] =
          (w['total'] as num).toDouble();
    }
    final monthly = [
      for (final m in j['monthly'] as List)
        (
          () {
            final key = (m as Map<String, dynamic>)['month'] as String; // YYYY-MM
            return '${monthLabel(int.parse(key.substring(0, 4)) * 100 + int.parse(key.substring(5, 7)))} ${key.substring(0, 4)}';
          }(),
          (m['income'] as num).toDouble(),
          (m['expense'] as num).toDouble()
        )
    ];
    final small = j['smallPayments'] as Map<String, dynamic>;
    final insights = _insights(income, expense, cats, topExp, merchants, wd,
        monthly, small['count'] as int, (small['total'] as num).toDouble());
    return Analysis._(const [], income, expense, span, cats, merchants, topExp,
        const [], wd, const {}, monthly, insights, j['transactionCount'] as int);
  }

  static List<String> _insights(
    double income,
    double expense,
    List<MapEntry<Category, double>> cats,
    List<Txn> topExp,
    List<(String, int, double)> merchants,
    List<double> wd,
    List<(String, double, double)> monthly,
    int smallCount,
    double smallTotal,
  ) {
    final maxWd = wd.fold(0.0, (a, b) => a > b ? a : b);
    final net = income - expense;
    return <String>[
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
      if (smallCount > 0)
        '$smallCount small payments under ₹100 added up to ${inr(smallTotal)}.',
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
  }
}
