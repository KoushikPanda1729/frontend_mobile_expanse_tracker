import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:expensetracker/commons/constants/app_colors.dart';
import 'package:expensetracker/commons/constants/app_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July', //
  'August', 'September', 'October', 'November', 'December',
];

class Category {
  final String name;
  final String icon;
  final Color color;
  const Category(this.name, this.icon, this.color);
}

const expenseCategories = [
  Category('Food', AppIcons.restaurantIcon, AppColors.red100),
  Category('Shopping', AppIcons.shoppingBagIcon, Color(0xFFFF8A3D)),
  Category('Travel', AppIcons.carIcon, Color(0xFF14B8A6)),
  Category('Recharge & Bills', AppIcons.recurringBillIcon, AppColors.violet100),
  Category('Health', AppIcons.warningIcon, AppColors.green100),
  Category('Insurance', AppIcons.file, Color(0xFFEC4899)),
  Category('Investment', AppIcons.currencyExchangeIcon, AppColors.blue100),
  Category('Transfer', AppIcons.transactionIcon, AppColors.yellow100),
];
const incomeCategories = [
  Category('Salary', AppIcons.salaryIcon, AppColors.green100),
  Category('Received', AppIcons.wallet3Icon, AppColors.green80),
];
final _byName = {
  for (final c in [...expenseCategories, ...incomeCategories]) c.name: c
};
Category categoryByName(String n) => _byName[n] ?? expenseCategories.last;

// ponytail: keyword rules, first match wins. Upgrade to user-editable rules if it misfiles often.
const _rules = {
  'vtaar': 'Salary', 'acme': 'Salary',
  'groww': 'Investment', 'policyba': 'Insurance',
  'airtel': 'Recharge & Bills', 'bharti': 'Recharge & Bills', 'jio': 'Recharge & Bills',
  'apollo': 'Health', 'uts': 'Travel', 'irctc': 'Travel',
  'zomato': 'Food', 'swiggy': 'Food',
};

class Txn {
  final DateTime date;
  final String merchant;
  final String mode; // UPI / IMPS / NEFT / Manual
  final Category category;
  final double amount;
  final bool isIncome;
  final String? ref; // bank reference, used to skip duplicates on import

  const Txn({
    required this.date,
    required this.merchant,
    required this.mode,
    required this.category,
    required this.amount,
    required this.isIncome,
    this.ref,
  });

  factory Txn.fromJson(Map<String, dynamic> j) {
    final raw = j['desc'] as String;
    final income = j['type'] == 'in';
    final low = raw.toLowerCase();
    final hit = _rules.entries.where((e) => low.contains(e.key)).firstOrNull;
    final d = (j['d'] as String).split('/');
    return Txn(
      date: DateTime(int.parse(d[2]), int.parse(d[1]), int.parse(d[0])),
      merchant: _merchant(raw),
      mode: raw.split(RegExp(r'[/*]')).first,
      category: hit != null
          ? categoryByName(hit.value)
          : (income ? incomeCategories.last : expenseCategories.last),
      amount: (j['amt'] as num).toDouble(),
      isIncome: income,
      ref: _ref(raw),
    );
  }

  factory Txn.fromStore(Map<String, dynamic> j) => Txn(
        date: DateTime.parse(j['d'] as String),
        merchant: j['m'] as String,
        mode: j['mo'] as String,
        category: categoryByName(j['c'] as String),
        amount: (j['a'] as num).toDouble(),
        isIncome: j['i'] as bool,
        ref: j['r'] as String?,
      );

  Map<String, dynamic> toStore() => {
        'd': date.toIso8601String(),
        'm': merchant,
        'mo': mode,
        'c': category.name,
        'a': amount,
        'i': isIncome,
        'r': ref,
      };

  String get key => ref != null
      ? 'r$ref'
      : '${date.toIso8601String()}|$amount|$isIncome|$merchant';

  static String? _ref(String raw) {
    final p = raw.split(RegExp(r'[/*]'));
    return p.length > 2 && RegExp(r'^\w{8,}$').hasMatch(p[2]) ? p[2] : null;
  }

  double get signed => isIncome ? amount : -amount;

  static String _merchant(String raw) {
    final p = raw.split('/');
    final m = raw.startsWith('UPI') && p.length > 3
        ? p[3]
        : raw.contains('*')
            ? raw.split('*').last
            : (p.length > 2 ? p.last : raw);
    return m.trim().isEmpty ? 'Unknown' : m.trim();
  }
}

class Ledger {
  final List<Txn> all; // oldest first
  final double opening;
  final bool demo; // true while showing the bundled dummy data
  const Ledger(this.all, this.opening, {this.demo = false});

  static int keyOf(DateTime d) => d.year * 100 + d.month;

  List<int> get monthKeys =>
      {for (final t in all) keyOf(t.date)}.toList()..sort();
  List<Txn> inMonth(int key) => all.where((t) => keyOf(t.date) == key).toList();

  double balanceAtEnd(int key) =>
      opening +
      all.where((t) => keyOf(t.date) <= key).fold(0.0, (a, t) => a + t.signed);

  Ledger add(Txn t) {
    final i = all.lastIndexWhere((x) => !x.date.isAfter(t.date));
    return Ledger([...all]..insert(i + 1, t), opening, demo: demo);
  }

  static double income(List<Txn> l) =>
      l.where((t) => t.isIncome).fold(0.0, (a, t) => a + t.amount);
  static double expense(List<Txn> l) =>
      l.where((t) => !t.isIncome).fold(0.0, (a, t) => a + t.amount);

  /// Expense (or income) total per category, biggest first.
  static List<MapEntry<Category, double>> byCategory(List<Txn> l,
      {bool income = false}) {
    final m = <Category, double>{};
    for (final t in l.where((t) => t.isIncome == income)) {
      m[t.category] = (m[t.category] ?? 0) + t.amount;
    }
    return m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }

  String toCsv() {
    final b = StringBuffer('date,type,category,merchant,mode,amount\n');
    for (final t in all) {
      b.writeln(
          '${t.date.toIso8601String().substring(0, 10)},${t.isIncome ? 'income' : 'expense'},'
          '${t.category.name},"${t.merchant}",${t.mode},${t.amount}');
    }
    return b.toString();
  }
}

class LedgerNotifier extends AsyncNotifier<Ledger> {
  static const _k = 'ledger_v1';

  @override
  Future<Ledger> build() async {
    try {
      final saved = (await SharedPreferences.getInstance()).getString(_k);
      if (saved != null) {
        final j = jsonDecode(saved) as Map<String, dynamic>;
        return Ledger([
          for (final m in j['t'] as List) Txn.fromStore(m as Map<String, dynamic>)
        ], (j['o'] as num).toDouble());
      }
    } catch (_) {} // no storage or corrupt data: fall back to dummy data
    final j = jsonDecode(
        await rootBundle.loadString('assets/data/transactions.json')) as List;
    final txns = [for (final m in j) Txn.fromJson(m as Map<String, dynamic>)];
    final opening =
        ((j.first as Map<String, dynamic>)['bal'] as num).toDouble() -
            txns.first.signed;
    return Ledger(txns, opening, demo: true);
  }

  Future<void> _save(Ledger l) async {
    if (l.demo) return;
    try {
      await (await SharedPreferences.getInstance()).setString(
          _k, jsonEncode({'o': l.opening, 't': [for (final t in l.all) t.toStore()]}));
    } catch (_) {}
  }

  /// Drop saved data and go back to the bundled sample data.
  Future<void> reset() async {
    try {
      await (await SharedPreferences.getInstance()).remove(_k);
    } catch (_) {}
    ref.invalidateSelf();
  }

  void add(Txn t) {
    final l = state.valueOrNull;
    if (l == null) return;
    final n = l.add(t);
    state = AsyncData(n);
    _save(n);
  }

  /// Merge parsed statement rows. First import replaces the dummy data.
  /// Returns (added, skipped-as-duplicate).
  (int, int) importTxns(List<Txn> incoming, double opening) {
    final cur = state.valueOrNull;
    if (cur == null || incoming.isEmpty) return (0, 0);
    final base = cur.demo ? <Txn>[] : cur.all;
    final seen = {for (final t in base) t.key};
    final fresh = [for (final t in incoming) if (seen.add(t.key)) t];
    final all = [...base, ...fresh];
    final order = [for (var i = 0; i < all.length; i++) (i, all[i])]..sort((a, b) {
        final c = a.$2.date.compareTo(b.$2.date);
        return c != 0 ? c : a.$1.compareTo(b.$1); // stable by original order
      });
    final earlier = base.isEmpty || incoming.first.date.isBefore(base.first.date);
    final next = Ledger([for (final o in order) o.$2], earlier ? opening : cur.opening);
    state = AsyncData(next);
    _save(next);
    return (fresh.length, incoming.length - fresh.length);
  }
}

final ledgerProvider =
    AsyncNotifierProvider<LedgerNotifier, Ledger>(LedgerNotifier.new);

/// Selected month as yyyymm; null = latest month in data.
final monthProvider = StateProvider<int?>((ref) => null);

/// Bottom-nav tab to jump to (0 home, 1 transaction, 2 budget, 3 profile).
final tabProvider = StateProvider<int>((ref) => 0);

/// Monthly budget limit per expense category.
final budgetsProvider = StateProvider<Map<String, double>>((ref) => {
      'Food': 3000,
      'Recharge & Bills': 1500,
      'Health': 1000,
      'Travel': 1000,
      'Investment': 8000,
      'Transfer': 5000,
    });

class TxnFilter {
  final String? type; // Income | Expense
  final String? sort; // Highest | Lowest | Newest | Oldest
  final Set<String> categories;
  final String query;
  const TxnFilter(
      {this.type, this.sort, this.categories = const {}, this.query = ''});

  TxnFilter withQuery(String q) =>
      TxnFilter(type: type, sort: sort, categories: categories, query: q);

  List<Txn> apply(List<Txn> l) {
    final q = query.toLowerCase();
    final r = l
        .where((t) =>
            (type == null || t.isIncome == (type == 'Income')) &&
            (categories.isEmpty || categories.contains(t.category.name)) &&
            (q.isEmpty ||
                t.merchant.toLowerCase().contains(q) ||
                t.category.name.toLowerCase().contains(q)))
        .toList();
    switch (sort) {
      case 'Highest':
        r.sort((a, b) => b.amount.compareTo(a.amount));
        return r;
      case 'Lowest':
        r.sort((a, b) => a.amount.compareTo(b.amount));
        return r;
      case 'Oldest':
        return r;
      default:
        return r.reversed.toList(); // Newest
    }
  }
}

final filterProvider = StateProvider<TxnFilter>((ref) => const TxnFilter());

String monthLabel(int key) => monthNames[key % 100 - 1];

String shortDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')} ${monthNames[d.month - 1].substring(0, 3)}';

/// Indian digit grouping, e.g. 1234567.5 -> ₹12,34,567.50
String inr(double v) {
  final neg = v < 0;
  final s = v.abs().toStringAsFixed(v == v.roundToDouble() ? 0 : 2);
  final parts = s.split('.');
  var d = parts[0];
  if (d.length > 3) {
    final head = d.substring(0, d.length - 3);
    d = '${head.replaceAllMapped(RegExp(r'(\d)(?=(\d\d)+$)'), (m) => '${m[1]},')},${d.substring(d.length - 3)}';
  }
  return '${neg ? '-' : ''}₹$d${parts.length > 1 ? '.${parts[1]}' : ''}';
}
