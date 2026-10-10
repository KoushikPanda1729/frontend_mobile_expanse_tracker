import 'dart:io';

import 'package:expensetracker/data/api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class StatementInfo {
  final String id, fileName, bank;
  final int sizeBytes, transactionCount;
  final DateTime? periodStart, periodEnd;
  final double? openingBalance, closingBalance;
  final bool wasLocked;
  final DateTime createdAt;

  const StatementInfo({
    required this.id,
    required this.fileName,
    required this.bank,
    required this.sizeBytes,
    required this.transactionCount,
    required this.periodStart,
    required this.periodEnd,
    required this.openingBalance,
    required this.closingBalance,
    required this.wasLocked,
    required this.createdAt,
  });

  factory StatementInfo.fromApi(Map<String, dynamic> j) => StatementInfo(
        id: j['id'] as String,
        fileName: j['fileName'] as String,
        bank: j['bank'] as String,
        sizeBytes: (j['sizeBytes'] as num).toInt(),
        transactionCount: j['transactionCount'] as int,
        periodStart: j['periodStart'] == null ? null : DateTime.parse(j['periodStart'] as String),
        periodEnd: j['periodEnd'] == null ? null : DateTime.parse(j['periodEnd'] as String),
        openingBalance: (j['openingBalance'] as num?)?.toDouble(),
        closingBalance: (j['closingBalance'] as num?)?.toDouble(),
        wasLocked: j['wasLocked'] as bool,
        createdAt: DateTime.parse(j['createdAt'] as String).toLocal(),
      );
}

/// GET /statements
final statementsProvider = FutureProvider.autoDispose<List<StatementInfo>>((ref) async {
  final j = await api.get('/statements') as Map<String, dynamic>;
  return [
    for (final m in j['items'] as List)
      StatementInfo.fromApi(m as Map<String, dynamic>)
  ];
});

/// Reads the stored PDF again and fills in details older imports did not save (UPI id, bank, reference).
/// Returns how many rows were updated.
Future<int> rereadStatement(String id) async {
  final j = await api.post('/statements/$id/reread') as Map<String, dynamic>;
  return j['updated'] as int;
}

/// DELETE /statements/:id (also removes the transactions imported from it).
Future<void> deleteStatement(String id) => api.delete('/statements/$id');

/// Fetches the stored PDF (unlocked, no password needed) into the temp folder.
Future<File> _fetchStatement(StatementInfo s) async {
  final bytes = await api.bytes('/statements/${s.id}/file');
  final dir = await getTemporaryDirectory();
  final base = s.fileName.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
  final f = File('${dir.path}/$base${s.wasLocked ? '-unlocked' : ''}.pdf');
  await f.writeAsBytes(bytes);
  return f;
}

/// Opens the PDF in the phone's PDF viewer.
Future<void> viewStatement(StatementInfo s) async {
  final f = await _fetchStatement(s);
  final r = await OpenFilex.open(f.path, type: 'application/pdf');
  if (r.type != ResultType.done) {
    throw const ApiException(0, 'NO_VIEWER', 'No app on this phone can open PDFs.');
  }
}

/// Opens the share sheet so the PDF can be saved to Files or sent.
Future<void> shareStatement(StatementInfo s) async {
  final f = await _fetchStatement(s);
  await Share.shareXFiles([XFile(f.path, mimeType: 'application/pdf')], subject: s.fileName);
}
