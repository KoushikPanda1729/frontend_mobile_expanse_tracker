import 'package:expensetracker/data/ledger.dart';

class ParsedStatement {
  final List<Txn> txns; // oldest first
  final double opening;
  const ParsedStatement(this.txns, this.opening);
}

/// Parses text extracted from an SBI account statement PDF.
/// Rows look like: `01/01/2026 01/01/2026 <description> <amount> <balance>`.
/// Debit vs credit is read from the balance change, so column layout doesn't matter.
// ponytail: SBI layout only. Add a parser per bank if you switch banks.
ParsedStatement? parseSbiStatement(String text) {
  final start = RegExp(r'(\d\d/\d\d/\d{4})\s+\d\d/\d\d/\d{4}\s+');
  final money = RegExp(r'([\d,]+\.\d\d)\s+([\d,]+\.\d\d)');
  final starts = start.allMatches(text).toList();
  double n(String s) => double.parse(s.replaceAll(',', ''));

  final rows = <Map<String, dynamic>>[];
  double? prev;
  for (var i = 0; i < starts.length; i++) {
    final end = i + 1 < starts.length ? starts[i + 1].start : text.length;
    final seg = text.substring(starts[i].end, end);
    final m = money.firstMatch(seg);
    if (m == null) continue;
    final desc =
        seg.substring(0, m.start).replaceAll(RegExp(r'\s+'), ' ').trim();
    final amt = n(m[1]!), bal = n(m[2]!);
    final isIn = prev != null
        ? (prev + amt - bal).abs() < 0.02
        : desc.contains('/CR/');
    prev = bal;
    rows.add({
      'd': starts[i][1],
      'desc': desc,
      'amt': amt,
      'bal': bal,
      'type': isIn ? 'in' : 'out',
    });
  }
  if (rows.isEmpty) return null;
  final txns = [for (final r in rows) Txn.fromJson(r)];
  final opening = (rows.first['bal'] as double) - txns.first.signed;
  return ParsedStatement(txns, opening);
}
