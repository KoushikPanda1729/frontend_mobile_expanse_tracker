import 'dart:convert';

import 'package:expensetracker/data/api.dart';
import 'package:expensetracker/data/ledger.dart';
import 'package:file_picker/file_picker.dart';

/// Let the user choose a PDF. Returns null when they cancel.
Future<PlatformFile?> pickStatementFile() async {
  final r = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['pdf'],
    withData: true,
  );
  return r?.files.single;
}

/// True when the bank's PDF is locked and the password is missing or wrong.
bool needsPdfPassword(Object e) =>
    e is ApiException &&
    (e.code == 'PDF_PASSWORD_REQUIRED' || e.code == 'PDF_PASSWORD_INCORRECT');

/// A hand-added entry that looks like a row of the statement. The user accepts or rejects it.
class ManualMatch {
  final String manualId, key; // key identifies the statement row
  final int daysApart; // 0 = same date, 1 = a day apart
  final DateTime manualDate, bankDate;
  final String manualName, bankName, manualCategory;
  final double amount;
  final bool isIncome;
  final String? note, label, upiId, ref;
  const ManualMatch({
    required this.manualId,
    required this.key,
    required this.daysApart,
    required this.manualDate,
    required this.bankDate,
    required this.manualName,
    required this.bankName,
    required this.manualCategory,
    required this.amount,
    required this.isIncome,
    required this.note,
    required this.label,
    required this.upiId,
    required this.ref,
  });

  factory ManualMatch.fromApi(Map<String, dynamic> j) {
    final m = j['manual'] as Map<String, dynamic>;
    final b = j['bank'] as Map<String, dynamic>;
    return ManualMatch(
      manualId: j['manualId'] as String,
      key: j['key'] as String,
      daysApart: j['daysApart'] as int,
      manualDate: DateTime.parse(m['date'] as String),
      bankDate: DateTime.parse(b['date'] as String),
      manualName: m['name'] as String,
      bankName: b['name'] as String,
      manualCategory: m['category'] as String,
      amount: (b['amount'] as num).toDouble(),
      isIncome: m['isIncome'] as bool,
      note: m['note'] as String?,
      label: m['label'] as String?,
      upiId: b['upiId'] as String?,
      ref: b['ref'] as String?,
    );
  }
}

/// A row the user already has that differs from what the statement says. Accept = take the bank's version.
class StatementChange {
  final String id; // the transaction
  final String signature; // identifies the bank's version, used to remember "keep mine"
  final List<String> fields; // what differs: date, amount, name, category
  final bool isIncome;
  final DateTime yoursDate, bankDate;
  final String yoursName, bankName, yoursCategory, bankCategory;
  final double yoursAmount, bankAmount;
  const StatementChange({
    required this.id,
    required this.signature,
    required this.fields,
    required this.isIncome,
    required this.yoursDate,
    required this.bankDate,
    required this.yoursName,
    required this.bankName,
    required this.yoursCategory,
    required this.bankCategory,
    required this.yoursAmount,
    required this.bankAmount,
  });

  factory StatementChange.fromApi(Map<String, dynamic> j) {
    final y = j['yours'] as Map<String, dynamic>;
    final b = j['bank'] as Map<String, dynamic>;
    return StatementChange(
      id: j['id'] as String,
      signature: j['signature'] as String,
      fields: [for (final f in j['fields'] as List) f as String],
      isIncome: j['isIncome'] as bool,
      yoursDate: DateTime.parse(y['date'] as String),
      bankDate: DateTime.parse(b['date'] as String),
      yoursName: y['name'] as String,
      bankName: b['name'] as String,
      yoursCategory: y['category'] as String,
      bankCategory: b['category'] as String,
      yoursAmount: (y['amount'] as num).toDouble(),
      bankAmount: (b['amount'] as num).toDouble(),
    );
  }
}

class UploadResult {
  final int added, skipped, merged, applied;
  const UploadResult(this.added, this.skipped, this.merged, this.applied);
}

/// What the server found in the PDF. Nothing is saved yet.
class StatementPreview {
  final bool alreadyUploaded;
  final int count, newCount, duplicateCount;
  final DateTime periodStart, periodEnd;
  final double income, expense;
  final List<Txn> sample; // first rows
  final List<ManualMatch> matches; // entries added by hand that look like rows of this file
  final List<StatementChange> changes; // rows the user has that differ from this file
  const StatementPreview({
    required this.alreadyUploaded,
    required this.count,
    required this.newCount,
    required this.duplicateCount,
    required this.periodStart,
    required this.periodEnd,
    required this.income,
    required this.expense,
    required this.sample,
    required this.matches,
    required this.changes,
  });

  factory StatementPreview.fromApi(Map<String, dynamic> j) => StatementPreview(
        alreadyUploaded: j['alreadyUploaded'] as bool,
        count: j['transactionCount'] as int,
        newCount: j['newCount'] as int,
        duplicateCount: j['duplicateCount'] as int,
        periodStart: DateTime.parse(j['periodStart'] as String),
        periodEnd: DateTime.parse(j['periodEnd'] as String),
        income: (j['income'] as num).toDouble(),
        expense: (j['expense'] as num).toDouble(),
        sample: [
          for (final m in j['sample'] as List)
            Txn(
              date: DateTime.parse((m as Map<String, dynamic>)['date'] as String),
              merchant: m['merchant'] as String,
              mode: '',
              category: categoryByName(m['category'] as String),
              amount: (m['amount'] as num).toDouble(),
              isIncome: m['isIncome'] as bool,
            )
        ],
        matches: [
          for (final m in j['manualMatches'] as List) ManualMatch.fromApi(m as Map<String, dynamic>)
        ],
        changes: [
          for (final c in j['changes'] as List) StatementChange.fromApi(c as Map<String, dynamic>)
        ],
      );
}

Map<String, String> _fields(String? password, bool save) => {
      if (password != null && password.isNotEmpty) 'password': password,
      if (save && password != null && password.isNotEmpty) 'savePassword': 'true',
    };

/// Step 1: the server reads the PDF (trying the saved passwords if it is locked).
/// Throws [ApiException]; check [needsPdfPassword] to ask for the password.
Future<StatementPreview> previewStatement(PlatformFile f, {String? password}) async {
  final j = await api.upload('POST', '/statements/preview',
      field: 'file', bytes: f.bytes!, filename: f.name, fields: _fields(password, false));
  return StatementPreview.fromApi(j as Map<String, dynamic>);
}

/// Step 2: store the file and import the rows. [merge] = the matches the user accepted.
Future<UploadResult> uploadStatement(PlatformFile f,
    {String? password,
    bool savePassword = false,
    List<ManualMatch> merge = const [],
    List<String> apply = const []}) async {
  final j = await api.upload('POST', '/statements',
      field: 'file',
      bytes: f.bytes!,
      filename: f.name,
      fields: {
        ..._fields(password, savePassword),
        if (merge.isNotEmpty)
          'merge': jsonEncode([for (final m in merge) {'manualId': m.manualId, 'key': m.key}]),
        if (apply.isNotEmpty) 'apply': jsonEncode(apply),
      }) as Map<String, dynamic>;
  return UploadResult(j['added'] as int, j['skippedDuplicates'] as int,
      (j['merged'] as int?) ?? 0, (j['applied'] as int?) ?? 0);
}

/// "Keep my version": remember it, so these rows are not offered again unless the bank's side changes.
Future<void> dismissChanges(List<StatementChange> changes) async {
  if (changes.isEmpty) return;
  await api.post('/statements/dismiss-changes', body: {
    'items': [for (final c in changes) {'id': c.id, 'signature': c.signature}],
  });
}
