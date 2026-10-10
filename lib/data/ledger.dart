
import 'package:expensetracker/data/api.dart';
import 'package:expensetracker/data/auth.dart';
import 'package:expensetracker/commons/constants/app_colors.dart';
import 'package:expensetracker/commons/constants/app_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July', //
  'August', 'September', 'October', 'November', 'December',
];

/// Monday .. Sunday for a date.
String weekdayName(DateTime d) =>
    const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][d.weekday - 1];

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
  Category('Education', AppIcons.file, Color(0xFF6366F1)),
  Category('Loans & EMI', AppIcons.wallet3Icon, Color(0xFF64748B)),
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

class Txn {
  final String? id; // server id, null for rows not saved yet
  final DateTime date;
  final String merchant;
  final String mode; // UPI / IMPS / NEFT / Manual
  final Category category;
  final double amount;
  final bool isIncome;
  final String? ref; // bank reference number
  final String? upiId; // UPI id or phone number of the other side
  final String? bank; // bank code of the other side
  final String? description; // what the bank printed
  final String? statementId; // null = entered by hand
  final String? note; // the user's own comment
  final String? label; // the user's own tag

  const Txn({
    this.id,
    required this.date,
    required this.merchant,
    required this.mode,
    required this.category,
    required this.amount,
    required this.isIncome,
    this.ref,
    this.upiId,
    this.bank,
    this.description,
    this.statementId,
    this.note,
    this.label,
  });

  factory Txn.fromApi(Map<String, dynamic> j) => Txn(
        id: j['id'] as String?,
        date: DateTime.parse(j['date'] as String), // YYYY-MM-DD, local midnight
        merchant: j['merchant'] as String,
        mode: j['mode'] as String,
        category: categoryByName(j['category'] as String),
        amount: (j['amount'] as num).toDouble(),
        isIncome: j['isIncome'] as bool,
        ref: j['ref'] as String?,
        upiId: j['upiId'] as String?,
        bank: j['bank'] as String?,
        description: j['description'] as String?,
        statementId: j['statementId'] as String?,
        note: j['note'] as String?,
        label: j['label'] as String?,
      );

  /// "Shopping · UPI · Lent": what a list row shows under the name.
  String get subtitle => [category.name, if (mode.isNotEmpty) mode, if (label != null) label!].join(' · ');

  /// The UPI id when it is a mobile number.
  String? get phone => upiId != null && RegExp(r'^[6-9]\d{9}$').hasMatch(upiId!) ? upiId : null;

  double get signed => isIncome ? amount : -amount;

  /// Cash and wallet entries are spending, but they never move the bank account's balance.
  bool get inBank => mode != 'Cash' && mode != 'Wallet';
}

class Ledger {
  final List<Txn> all; // oldest first
  final double opening;
  const Ledger(this.all, this.opening);

  static int keyOf(DateTime d) => d.year * 100 + d.month;

  /// Months that have transactions, oldest first. Never empty: a new account gets this month.
  List<int> get monthKeys {
    final k = {for (final t in all) keyOf(t.date)}.toList()..sort();
    return k.isEmpty ? [keyOf(DateTime.now())] : k;
  }
  /// A period key is a month (yyyymm), [allTime] (0) or minus N for the last N months with data
  /// up to the newest transaction (-3 = last 3 months).
  static const allTime = 0;

  List<Txn> inMonth(int key) {
    if (key > 0) return all.where((t) => keyOf(t.date) == key).toList();
    if (key == allTime || all.isEmpty) return all;
    final last = all.last.date;
    final start = DateTime(last.year, last.month + key + 1, 1);
    return all.where((t) => !t.date.isBefore(start)).toList();
  }

  /// First and last day of a period key (a month, [allTime] or the last N months). null = everything.
  (DateTime, DateTime)? rangeOf(int key) {
    if (key == allTime || all.isEmpty) return null;
    if (key > 0) return (DateTime(key ~/ 100, key % 100, 1), DateTime(key ~/ 100, key % 100 + 1, 0));
    final last = all.last.date;
    return (DateTime(last.year, last.month + key + 1, 1), DateTime(last.year, last.month + 1, 0));
  }

  /// Balance at the end of a month, or at the newest transaction for a range.
  double balanceAtEnd(int key) =>
      opening +
      all
          .where((t) => t.inBank && (key <= 0 || keyOf(t.date) <= key))
          .fold(0.0, (a, t) => a + t.signed);

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
  @override
  Future<Ledger> build() async {
    // a new user (login/logout) starts from a fresh load
    if (ref.watch(authProvider).valueOrNull != true) return const Ledger([], 0);
    return _fetch();
  }

  /// Every transaction of the account, oldest first (pages of 200).
  Future<Ledger> _fetch() async {
    final all = <Txn>[];
    String? cursor;
    do {
      final j = await api.get('/transactions', query: {
        'sort': 'oldest',
        'limit': '200',
        if (cursor != null) 'cursor': cursor,
      }) as Map<String, dynamic>;
      all.addAll([
        for (final m in j['items'] as List) Txn.fromApi(m as Map<String, dynamic>)
      ]);
      cursor = j['nextCursor'] as String?;
    } while (cursor != null);
    if (all.isEmpty) return const Ledger([], 0);
    final me = await api.get('/users/me') as Map<String, dynamic>;
    return Ledger(all, (me['openingBalance'] as num).toDouble());
  }

  /// Reload from the server (after an import, edit or delete).
  Future<void> refresh() async {
    final l = await _fetch();
    // the picked month may be gone now (its last transaction was deleted)
    final k = ref.read(monthProvider);
    if (k != null && k > 0 && !l.monthKeys.contains(k)) {
      ref.read(monthProvider.notifier).state = null;
    }
    state = AsyncData(l);
  }

  /// Saves a manual entry. Throws [ApiException] if the server refuses.
  Future<void> add(Txn t) async {
    await api.post('/transactions', body: {
      'date': t.date.toIso8601String().substring(0, 10),
      'merchant': t.merchant,
      'category': t.category.name,
      'amount': t.amount,
      'isIncome': t.isIncome,
      'mode': t.mode,
      if (t.label != null) 'label': t.label,
      if (t.note != null) 'note': t.note,
    });
    await refresh();
  }

  /// Changes a saved transaction (PATCH). Throws [ApiException] if the server refuses.
  Future<void> edit(String id, Txn t) async {
    await api.patch('/transactions/$id', body: {
      'date': t.date.toIso8601String().substring(0, 10),
      'merchant': t.merchant,
      'category': t.category.name,
      'amount': t.amount,
      'note': t.note ?? '', // an empty string clears it
      'label': t.label ?? '',
      if (t.mode.isNotEmpty) 'mode': t.mode,
    });
    await refresh();
  }

  /// Moves every transaction of [merchant] (same direction) to [category]. Returns how many changed.
  Future<int> recategorize(String merchant, String category, bool isIncome) async {
    final j = await api.patch('/transactions/recategorize', body: {
      'merchant': merchant,
      'category': category,
      'isIncome': isIncome,
    }) as Map<String, dynamic>;
    await refresh();
    return j['updated'] as int;
  }

  Future<void> remove(String id) async {
    await api.delete('/transactions/$id');
    await refresh();
  }
}

final ledgerProvider =
    AsyncNotifierProvider<LedgerNotifier, Ledger>(LedgerNotifier.new);

/// Selected month as yyyymm; null = latest month in data.
final monthProvider = StateProvider<int?>((ref) => null);

/// Bottom-nav tab to jump to (0 home, 1 transaction, 2 budget, 3 profile).
final tabProvider = StateProvider<int>((ref) => 0);

/// Monthly budget limit per expense category, kept on the server.
final budgetsProvider =
    NotifierProvider<BudgetsNotifier, Map<String, double>>(BudgetsNotifier.new);

class BudgetsNotifier extends Notifier<Map<String, double>> {
  @override
  Map<String, double> build() {
    if (ref.watch(authProvider).valueOrNull == true) _load();
    return const {};
  }

  Future<void> _load() async {
    try {
      final j = await api.get('/budgets') as Map<String, dynamic>;
      state = {
        for (final b in j['items'] as List)
          (b as Map<String, dynamic>)['category'] as String:
              (b['limit'] as num).toDouble()
      };
    } catch (_) {} // offline: no budgets shown
  }

  String _path(String category) => '/budgets/${Uri.encodeComponent(category)}';

  /// Shows the change at once and undoes it if the server refuses.
  Future<void> set(String category, double limit) async {
    final prev = state;
    state = {...prev, category: limit};
    try {
      await api.put(_path(category), body: {'limit': limit});
    } catch (_) {
      state = prev;
      rethrow;
    }
  }

  Future<void> remove(String category) async {
    final prev = state;
    state = {...prev}..remove(category);
    try {
      await api.delete(_path(category));
    } catch (_) {
      state = prev;
      rethrow;
    }
  }
}

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
                t.category.name.toLowerCase().contains(q) ||
                (t.label ?? '').toLowerCase().contains(q) ||
                (t.note ?? '').toLowerCase().contains(q)))
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

String monthLabel(int key) => key > 0
    ? monthNames[key % 100 - 1]
    : key == Ledger.allTime
        ? 'All time'
        : 'Last ${-key} months';

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
