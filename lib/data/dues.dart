import 'package:expensetracker/data/analytics.dart' show ymd;
import 'package:expensetracker/data/api.dart';
import 'package:expensetracker/data/auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Money a person owes the user ([toGet]) or the user owes a person ([toGive]). Not part of the transactions.
class Due {
  final String id, person, direction; // direction: 'get' = they owe me, 'give' = I owe them
  final double amount, settled, remaining;
  final String? note;
  final DateTime? dueDate;
  const Due({
    required this.id,
    required this.person,
    required this.direction,
    required this.amount,
    required this.settled,
    required this.remaining,
    required this.note,
    required this.dueDate,
  });

  bool get toGet => direction == 'get';
  bool get isOpen => remaining > 0;
  bool get overdue =>
      isOpen && dueDate != null && dueDate!.isBefore(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day));

  factory Due.fromApi(Map<String, dynamic> j) => Due(
        id: j['id'] as String,
        person: j['person'] as String,
        direction: j['direction'] as String,
        amount: (j['amount'] as num).toDouble(),
        settled: (j['settled'] as num).toDouble(),
        remaining: (j['remaining'] as num).toDouble(),
        note: j['note'] as String?,
        dueDate: j['dueDate'] == null ? null : DateTime.parse(j['dueDate'] as String),
      );
}

class DuesData {
  final List<Due> items;
  final double toGet, toGive; // what is still open
  const DuesData(this.items, this.toGet, this.toGive);
}

/// GET /dues
final duesProvider = FutureProvider.autoDispose<DuesData>((ref) async {
  ref.watch(authProvider);
  final j = await api.get('/dues') as Map<String, dynamic>;
  final t = j['totals'] as Map<String, dynamic>;
  return DuesData(
    [for (final m in j['items'] as List) Due.fromApi(m as Map<String, dynamic>)],
    (t['toGet'] as num).toDouble(),
    (t['toGive'] as num).toDouble(),
  );
});

Future<void> addDue({
  required String person,
  required bool toGet,
  required double amount,
  String? note,
  DateTime? dueDate,
}) =>
    api.post('/dues', body: {
      'person': person,
      'direction': toGet ? 'get' : 'give',
      'amount': amount,
      if (note != null && note.isNotEmpty) 'note': note,
      if (dueDate != null) 'dueDate': ymd(dueDate),
    });

Future<void> updateDue(String id,
        {required String person, required bool toGet, required double amount, required String note, DateTime? dueDate}) =>
    api.patch('/dues/$id', body: {
      'person': person,
      'direction': toGet ? 'get' : 'give',
      'amount': amount,
      'note': note, // '' clears it
      'dueDate': dueDate == null ? null : ymd(dueDate),
    });

/// Record a (part) payment.
Future<void> settleDue(String id, double amount) => api.post('/dues/$id/settle', body: {'amount': amount});

Future<void> deleteDue(String id) => api.delete('/dues/$id');
