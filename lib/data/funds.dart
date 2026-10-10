import 'package:expensetracker/data/analytics.dart' show ymd;
import 'package:expensetracker/data/api.dart';
import 'package:expensetracker/data/auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class Fund {
  final String id, name;
  /// The total invested to show: what the user typed from the fund app, or what the bank statements add up to.
  final double invested;
  final double? investedTotal; // as typed, null until the user types it
  final double? currentValue; // as typed, null until the user types it
  final double? gain, gainPercent; // returns and percentage: worked out from the invested and current value
  final double? monthlySip; // the latest statement payment into the fund
  final double fromStatements; // what the bank statements show went in
  final int entryCount;
  final DateTime? lastEntry, valueAsOf;
  const Fund({
    required this.id,
    required this.name,
    required this.invested,
    required this.investedTotal,
    required this.currentValue,
    required this.gain,
    required this.gainPercent,
    required this.monthlySip,
    required this.fromStatements,
    required this.entryCount,
    required this.lastEntry,
    required this.valueAsOf,
  });

  factory Fund.fromApi(Map<String, dynamic> j) => Fund(
        id: j['id'] as String,
        name: j['name'] as String,
        invested: (j['invested'] as num).toDouble(),
        investedTotal: (j['investedTotal'] as num?)?.toDouble(),
        currentValue: (j['currentValue'] as num?)?.toDouble(),
        gain: (j['gain'] as num?)?.toDouble(),
        gainPercent: (j['gainPercent'] as num?)?.toDouble(),
        monthlySip: (j['monthlySip'] as num?)?.toDouble(),
        fromStatements: (j['fromStatements'] as num).toDouble(),
        entryCount: j['entryCount'] as int,
        lastEntry: j['lastEntry'] == null ? null : DateTime.parse(j['lastEntry'] as String),
        valueAsOf: j['valueAsOf'] == null ? null : DateTime.parse(j['valueAsOf'] as String),
      );
}

class FundEntry {
  final String id, kind; // 'invest' | 'withdraw'
  final DateTime date;
  final double amount;
  final String? note;
  final bool fromStatement;
  const FundEntry(this.id, this.kind, this.date, this.amount, this.note, this.fromStatement);

  bool get withdraw => kind == 'withdraw';
}

class FundDetail {
  final Fund fund;
  final List<FundEntry> entries;
  const FundDetail(this.fund, this.entries);
}

class FundsData {
  final List<Fund> items;
  final double invested; // total invested across all funds
  final double? currentValue, returns; // over the funds whose current value was typed
  final double investedInValued; // what went into those funds, for the overall percentage
  final double monthlySip; // the monthly SIPs added up
  const FundsData(this.items, this.invested, this.currentValue, this.returns, this.investedInValued, this.monthlySip);
}

/// A bank statement payment (category Investment) that is not in any fund yet.
class Unassigned {
  final String id, merchant;
  final DateTime date;
  final double amount;
  const Unassigned(this.id, this.merchant, this.date, this.amount);
}

/// GET /funds
final fundsProvider = FutureProvider.autoDispose<FundsData>((ref) async {
  ref.watch(authProvider);
  final j = await api.get('/funds') as Map<String, dynamic>;
  final t = j['totals'] as Map<String, dynamic>;
  return FundsData(
    [for (final m in j['items'] as List) Fund.fromApi(m as Map<String, dynamic>)],
    (t['invested'] as num).toDouble(),
    (t['currentValue'] as num?)?.toDouble(),
    (t['returns'] as num?)?.toDouble(),
    (t['investedInValued'] as num).toDouble(),
    (t['monthlySip'] as num).toDouble(),
  );
});

/// GET /funds/:id
final fundDetailProvider = FutureProvider.autoDispose.family<FundDetail, String>((ref, id) async {
  final j = await api.get('/funds/$id') as Map<String, dynamic>;
  return FundDetail(Fund.fromApi(j), [
    for (final e in j['entries'] as List)
      FundEntry(
        (e as Map<String, dynamic>)['id'] as String,
        e['kind'] as String,
        DateTime.parse(e['date'] as String),
        (e['amount'] as num).toDouble(),
        e['note'] as String?,
        e['fromStatement'] as bool,
      )
  ]);
});

/// GET /funds/unassigned: investment payments found in the bank statements.
final unassignedProvider = FutureProvider.autoDispose<List<Unassigned>>((ref) async {
  ref.watch(authProvider);
  final j = await api.get('/funds/unassigned') as Map<String, dynamic>;
  return [
    for (final m in j['items'] as List)
      Unassigned((m as Map<String, dynamic>)['id'] as String, m['merchant'] as String,
          DateTime.parse(m['date'] as String), (m['amount'] as num).toDouble())
  ];
});

Future<String> addFund(String name, {double? investedTotal}) async {
  final j = await api.post('/funds', body: {'name': name, if (investedTotal != null) 'investedTotal': investedTotal})
      as Map<String, dynamic>;
  return j['id'] as String;
}

Future<void> renameFund(String id, String name) => api.patch('/funds/$id', body: {'name': name});

/// The total invested and the current value, each saved exactly as typed from the fund app (null clears it).
/// The returns and the percentage are worked out from these two.
Future<void> setFundValue(String id, {double? invested, double? current, double? sip}) =>
    api.patch('/funds/$id', body: {'investedTotal': invested, 'currentValue': current, 'monthlySip': sip});

Future<void> deleteFund(String id) => api.delete('/funds/$id');

Future<void> addFundEntry(String fundId,
        {required DateTime date, required double amount, bool withdraw = false, String? note}) =>
    api.post('/funds/$fundId/entries', body: {
      'date': ymd(date),
      'amount': amount,
      'kind': withdraw ? 'withdraw' : 'invest',
      if (note != null && note.isNotEmpty) 'note': note,
    });

Future<void> deleteFundEntry(String entryId) => api.delete('/funds/entries/$entryId');

/// Put bank statement payments into a fund. Returns how many were added.
Future<int> assignToFund(String fundId, List<String> txnIds) async {
  final j = await api.post('/funds/$fundId/assign', body: {'txnIds': txnIds}) as Map<String, dynamic>;
  return j['added'] as int;
}
