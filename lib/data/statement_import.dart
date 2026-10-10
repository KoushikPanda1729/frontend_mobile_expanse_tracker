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

/// What the server found in the PDF. Nothing is saved yet.
class StatementPreview {
  final bool alreadyUploaded;
  final int count, newCount, duplicateCount;
  final DateTime periodStart, periodEnd;
  final double income, expense;
  final List<Txn> sample; // first rows
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

/// Step 2: store the file and import the rows. Returns (added, skipped as duplicates).
Future<(int, int)> uploadStatement(PlatformFile f,
    {String? password, bool savePassword = false}) async {
  final j = await api.upload('POST', '/statements',
      field: 'file',
      bytes: f.bytes!,
      filename: f.name,
      fields: _fields(password, savePassword)) as Map<String, dynamic>;
  return (j['added'] as int, j['skippedDuplicates'] as int);
}
