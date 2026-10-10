import 'package:expensetracker/commons/components/button/app/solid_button_widget.dart';
import 'package:expensetracker/commons/constants/app_colors.dart';
import 'package:expensetracker/data/api.dart';
import 'package:expensetracker/data/ledger.dart';
import 'package:expensetracker/data/review.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A label and a value, with a copy button (phone numbers and reference numbers are meant to be searched elsewhere).
Widget copyRow(BuildContext context, String label, String value, {bool copy = true}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        SizedBox(
          width: 92,
          child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        ),
        if (copy)
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text('$label copied')));
            },
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.copy, size: 16, color: AppColors.violet100),
            ),
          ),
      ],
    ),
  );
}

/// Quick labels: what the payee is -> the category its payments go to.
const _presets = [
  ('Friend / family', 'Transfer'),
  ('Rent', 'Transfer'),
  ('Grocery / shop', 'Shopping'),
  ('Food', 'Food'),
  ('Medical', 'Health'),
  ('Travel', 'Travel'),
  ('Education', 'Education'),
  ('Bills', 'Recharge & Bills'),
  ('Loan / EMI', 'Loans & EMI'),
];

/// "I know this payee": pick what it is. Saved once, so every payment (old and in later imports) follows it.
Future<void> showLabelPayeeSheet(BuildContext context, WidgetRef ref, String merchant) async {
  final messenger = ScaffoldMessenger.of(context);
  final label = TextEditingController();
  var category = 'Transfer';
  var busy = false;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheet) => StatefulBuilder(
      builder: (_, setS) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 20, 16, 16 + MediaQuery.of(sheet).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Who is $merchant?',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Tell the app once. Every payment to $merchant, now and in later imports, follows it.',
                  style: TextStyle(color: Colors.grey[600], height: 1.35)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in _presets)
                    ChoiceChip(
                      label: Text(p.$1),
                      selected: label.text == p.$1,
                      onSelected: (_) => setS(() {
                        label.text = p.$1;
                        category = p.$2;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: label,
                onChanged: (_) => setS(() {}),
                decoration: const InputDecoration(
                    labelText: 'Name or note (optional)',
                    hintText: 'e.g. Ramesh tea stall',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Text('Category', style: TextStyle(color: Colors.grey[700], fontSize: 13)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in expenseCategories)
                    ChoiceChip(
                      label: Text(c.name),
                      selected: category == c.name,
                      onSelected: (_) => setS(() => category = c.name),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              SolidButtonWidget(
                label: busy ? 'Saving...' : 'Save',
                onPressed: busy
                    ? null
                    : () async {
                        setS(() => busy = true);
                        try {
                          await labelPayee(merchant, category, label.text);
                          await ref.read(ledgerProvider.notifier).refresh();
                          if (sheet.mounted) Navigator.pop(sheet);
                          messenger.showSnackBar(SnackBar(
                              content: Text('$merchant saved as ${label.text.isEmpty ? category : label.text}')));
                        } catch (e) {
                          if (sheet.mounted) setS(() => busy = false);
                          messenger.showSnackBar(SnackBar(
                              content: Text(e is ApiException ? e.message : 'Could not save.')));
                        }
                      },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
