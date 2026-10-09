import 'dart:typed_data';

import 'package:expensetracker/data/statement_parser.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class NeedsPassword implements Exception {}

/// Let the user choose a PDF. Returns null when they cancel.
Future<PlatformFile?> pickStatementFile() async {
  final r = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['pdf'],
    withData: true,
  );
  return r?.files.single;
}

/// Reads the PDF text and parses it. Returns null if no transactions were found.
/// Throws [NeedsPassword] when the PDF is protected and [password] is missing or wrong.
ParsedStatement? readStatement(Uint8List bytes, {String? password}) {
  final PdfDocument doc;
  try {
    doc = PdfDocument(inputBytes: bytes, password: password);
  } catch (e) {
    if (e.toString().toLowerCase().contains('password')) throw NeedsPassword();
    rethrow;
  }
  final text = PdfTextExtractor(doc).extractText();
  doc.dispose();
  return parseSbiStatement(text);
}
