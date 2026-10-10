import 'package:expensetracker/data/analysis.dart';
import 'package:expensetracker/data/api.dart';
import 'package:expensetracker/data/ledger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// YYYY-MM-DD, the date format of the API.
String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// All of these watch the ledger, so they reload after an import, edit or delete.

/// GET /analytics/summary for a date range. null = no transactions in it.
final summaryProvider = FutureProvider.autoDispose
    .family<Analysis?, (String, String)>((ref, range) async {
  ref.watch(ledgerProvider);
  final j = await api.get('/analytics/summary',
      query: {'from': range.$1, 'to': range.$2}) as Map<String, dynamic>;
  return (j['transactionCount'] as int) == 0 ? null : Analysis.fromSummary(j);
});

/// The real account balance (GET /analytics/account): the SBI header balance of the newest statement,
/// plus anything dated after it.
class AccountInfo {
  final double balance;
  final DateTime? asOf;
  final bool fromHeader; // the bank's own "Balance as on" figure
  final double? untrackedAmount; // money that moved after the last statement and is not imported yet
  final DateTime? untrackedFrom, untrackedTo;
  final List<(DateTime, DateTime)> gaps; // between two statements that do not join up
  final int statementCount;
  const AccountInfo({
    required this.balance,
    required this.asOf,
    required this.fromHeader,
    required this.untrackedAmount,
    required this.untrackedFrom,
    required this.untrackedTo,
    required this.gaps,
    required this.statementCount,
  });

  factory AccountInfo.fromApi(Map<String, dynamic> j) {
    final u = j['untracked'] as Map<String, dynamic>?;
    return AccountInfo(
      balance: (j['balance'] as num).toDouble(),
      asOf: j['asOf'] == null ? null : DateTime.parse(j['asOf'] as String),
      fromHeader: j['source'] == 'statement-header',
      untrackedAmount: (u?['amount'] as num?)?.toDouble(),
      untrackedFrom: u == null ? null : DateTime.parse(u['from'] as String),
      untrackedTo: u == null ? null : DateTime.parse(u['to'] as String),
      gaps: [
        for (final g in j['gaps'] as List)
          (
            DateTime.parse((g as Map<String, dynamic>)['from'] as String),
            DateTime.parse(g['to'] as String)
          )
      ],
      statementCount: j['statementCount'] as int,
    );
  }
}

final accountProvider = FutureProvider.autoDispose<AccountInfo>((ref) async {
  ref.watch(ledgerProvider);
  return AccountInfo.fromApi(await api.get('/analytics/account') as Map<String, dynamic>);
});

/// GET /analytics/balance: account balance at the end of [asOf] (YYYY-MM-DD).
final balanceProvider =
    FutureProvider.autoDispose.family<double, String>((ref, asOf) async {
  ref.watch(ledgerProvider);
  final j = await api.get('/analytics/balance', query: {'asOf': asOf})
      as Map<String, dynamic>;
  return (j['balance'] as num).toDouble();
});

/// GET /analytics/series: spend per day / week (Monday start) / month. Empty buckets are left out.
final seriesProvider = FutureProvider.autoDispose
    .family<List<(DateTime, double)>, (String, String?, String?)>((ref, q) async {
  ref.watch(ledgerProvider);
  final j = await api.get('/analytics/series', query: {
    'granularity': q.$1,
    if (q.$2 != null) 'from': q.$2!,
    if (q.$3 != null) 'to': q.$3!,
  }) as Map<String, dynamic>;
  return [
    for (final m in j['items'] as List)
      (
        DateTime.parse((m as Map<String, dynamic>)['bucket'] as String),
        (m['expense'] as num).toDouble()
      )
  ];
});

/// GET /analytics/balance-trend: running balance at the end of each day with transactions.
final balanceTrendProvider = FutureProvider.autoDispose
    .family<List<(DateTime, double)>, (String, String)>((ref, range) async {
  ref.watch(ledgerProvider);
  final j = await api.get('/analytics/balance-trend',
      query: {'from': range.$1, 'to': range.$2}) as Map<String, dynamic>;
  return [
    for (final m in j['items'] as List)
      (
        DateTime.parse((m as Map<String, dynamic>)['date'] as String),
        (m['balance'] as num).toDouble()
      )
  ];
});
