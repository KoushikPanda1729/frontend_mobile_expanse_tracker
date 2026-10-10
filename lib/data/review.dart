import 'package:expensetracker/data/analytics.dart' show ymd;
import 'package:expensetracker/data/api.dart';
import 'package:expensetracker/data/ledger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A person or shop the bank only gave a short name for, and the user has not labelled yet.
class UnknownPayee {
  final String merchant;
  final double sent, received, net;
  final int sentCount, receivedCount;
  final DateTime first, last;
  final String? upiId, phone, bank;
  const UnknownPayee({
    required this.merchant,
    required this.sent,
    required this.received,
    required this.net,
    required this.sentCount,
    required this.receivedCount,
    required this.first,
    required this.last,
    required this.upiId,
    required this.phone,
    required this.bank,
  });

  factory UnknownPayee.fromApi(Map<String, dynamic> j) => UnknownPayee(
        merchant: j['merchant'] as String,
        sent: (j['sent'] as num).toDouble(),
        received: (j['received'] as num).toDouble(),
        net: (j['net'] as num).toDouble(),
        sentCount: j['sentCount'] as int,
        receivedCount: j['receivedCount'] as int,
        first: DateTime.parse(j['first'] as String),
        last: DateTime.parse(j['last'] as String),
        upiId: j['upiId'] as String?,
        phone: j['phone'] as String?,
        bank: j['bank'] as String?,
      );
}

/// One payment worth a look, with why.
class FlaggedTxn {
  final String id, merchant, category;
  final DateTime date;
  final double amount;
  final List<String> reasons;
  final String? upiId, phone, bank, ref, description;
  const FlaggedTxn({
    required this.id,
    required this.merchant,
    required this.category,
    required this.date,
    required this.amount,
    required this.reasons,
    required this.upiId,
    required this.phone,
    required this.bank,
    required this.ref,
    required this.description,
  });

  factory FlaggedTxn.fromApi(Map<String, dynamic> j) => FlaggedTxn(
        id: j['id'] as String,
        merchant: j['merchant'] as String,
        category: j['category'] as String,
        date: DateTime.parse(j['date'] as String),
        amount: (j['amount'] as num).toDouble(),
        reasons: [for (final r in j['reasons'] as List) r as String],
        upiId: j['upiId'] as String?,
        phone: j['phone'] as String?,
        bank: j['bank'] as String?,
        ref: j['ref'] as String?,
        description: j['description'] as String?,
      );
}

class Review {
  final List<UnknownPayee> payees;
  final List<FlaggedTxn> flagged;
  final double unknownSent, flaggedAmount;
  const Review(this.payees, this.flagged, this.unknownSent, this.flaggedAmount);

  /// Number of things to look at.
  int get count => payees.length + flagged.length;

  factory Review.fromApi(Map<String, dynamic> j) {
    final t = j['totals'] as Map<String, dynamic>;
    return Review(
      [for (final p in j['unknownPayees'] as List) UnknownPayee.fromApi(p as Map<String, dynamic>)],
      [for (final f in j['flagged'] as List) FlaggedTxn.fromApi(f as Map<String, dynamic>)],
      (t['unknownSent'] as num).toDouble(),
      (t['flaggedAmount'] as num).toDouble(),
    );
  }
}

/// GET /analytics/review for a date range ((null, null) = everything). Reloads when the ledger changes.
final reviewProvider =
    FutureProvider.autoDispose.family<Review, (String?, String?)>((ref, range) async {
  ref.watch(ledgerProvider);
  return Review.fromApi(await api.get('/analytics/review', query: {
    if (range.$1 != null) 'from': range.$1!,
    if (range.$2 != null) 'to': range.$2!,
  }) as Map<String, dynamic>);
});

/// The review for the period picked in the month pill (shared with Home and Transactions).
final reviewForPeriodProvider = Provider.autoDispose<AsyncValue<Review>>((ref) {
  final ledger = ref.watch(ledgerProvider).valueOrNull;
  final picked = ref.watch(monthProvider);
  final key = picked ?? (ledger?.monthKeys.last ?? Ledger.allTime);
  final r = ledger?.rangeOf(key);
  return ref.watch(reviewProvider(r == null ? (null, null) : (ymd(r.$1), ymd(r.$2))));
});

/// "I know this payee": remembers it, moves its payments to [category] and applies to later imports.
Future<void> labelPayee(String merchant, String category, String? label) => api.put('/payees', body: {
      'merchant': merchant,
      'category': category,
      if (label != null && label.trim().isNotEmpty) 'label': label.trim(),
    });
