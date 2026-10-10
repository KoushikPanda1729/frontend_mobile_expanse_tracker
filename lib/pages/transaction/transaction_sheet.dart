import 'package:expensetracker/commons/components/sheets/app_sheets.dart';
import 'package:expensetracker/commons/components/button/app/solid_button_widget.dart';
import 'package:expensetracker/commons/constants/app_colors.dart';
import 'package:expensetracker/data/api.dart';
import 'package:expensetracker/data/ledger.dart';
import 'package:expensetracker/data/payment_methods.dart';
import 'package:expensetracker/pages/review/review_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

bool _deleting = false; // one delete at a time

const _shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)));

String _err(Object e) => e is ApiException ? e.message : 'Something went wrong.';

/// Details of one transaction, with Edit and Delete for saved ones.
/// Sample rows (not on the server yet) are read-only.
void showTransactionSheet(BuildContext context, WidgetRef ref, Txn t) {
  final messenger = ScaffoldMessenger.of(context);
  final saved = t.id != null;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: _shape,
    builder: (sheet) {
      Widget row(String k, String v) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(k, style: TextStyle(color: Colors.grey[600])),
                Flexible(
                  child: Text(v,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          );
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.merchant,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('${t.isIncome ? '+' : '-'} ${inr(t.amount)}',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: t.isIncome ? AppColors.green100 : AppColors.red100)),
              const SizedBox(height: 12),
              row('Category', t.category.name),
              row('Date', '${shortDate(t.date)} ${t.date.year}'),
              row('Type', t.isIncome ? 'Income' : 'Expense'),
              if (t.mode.isNotEmpty) row('Mode', t.mode),
              if (t.phone != null) copyRow(sheet, 'Phone', t.phone!),
              if (t.upiId != null && t.phone == null) copyRow(sheet, 'UPI id', t.upiId!),
              if (t.bank != null) row('Bank', t.bank!),
              if (t.ref != null) copyRow(sheet, 'Reference', t.ref!),
              if (t.label != null) row('Label', t.label!),
              if (t.note != null) ...[
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: AppColors.violet20.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.sticky_note_2_outlined,
                          size: 18, color: AppColors.violet100),
                      const SizedBox(width: 8),
                      Expanded(child: Text(t.note!, style: const TextStyle(height: 1.35))),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (saved)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.violet100,
                    side: const BorderSide(color: AppColors.violet100),
                    minimumSize: const Size.fromHeight(44),
                  ),
                  onPressed: () {
                    Navigator.pop(sheet);
                    showEditTransactionSheet(context, ref, t, focusNote: true);
                  },
                  icon: const Icon(Icons.edit_note, size: 20),
                  label: Text(t.note == null && t.label == null
                      ? 'Add a note or label'
                      : 'Change note or label'),
                ),
              if (saved && !t.isIncome && t.mode != 'Manual')
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(sheet);
                    showLabelPayeeSheet(context, ref, t.merchant);
                  },
                  icon: const Icon(Icons.person_search_outlined, size: 18),
                  label: Text('Who is ${t.merchant}? Label this payee'),
                ),
              if (!saved)
                Text('Sample data. Import a statement or add a transaction to edit.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13))
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.delete_outline,
                            color: AppColors.red100),
                        label: const Text('Delete',
                            style: TextStyle(color: AppColors.red100)),
                        onPressed: () async {
                          if (_deleting) return;
                          _deleting = true;
                          try {
                          final ok = await showAppSheet<bool>(
                            context: sheet,
                            builder: (d) => SheetFrame(
                              title: const Text('Delete transaction?'),
                              content: Text(
                                  '${t.merchant}, ${inr(t.amount)} will be removed.'),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(d, false),
                                    child: const Text('Cancel')),
                                TextButton(
                                    onPressed: () => Navigator.pop(d, true),
                                    child: const Text('Delete',
                                        style:
                                            TextStyle(color: AppColors.red100))),
                              ],
                            ),
                          );
                          if (ok != true) return;
                          try {
                            await ref.read(ledgerProvider.notifier).remove(t.id!);
                            if (sheet.mounted) Navigator.pop(sheet);
                            messenger.showSnackBar(
                                const SnackBar(content: Text('Transaction deleted')));
                          } catch (e) {
                            messenger.showSnackBar(SnackBar(content: Text(_err(e))));
                          }
                          } finally {
                            _deleting = false;
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SolidButtonWidget(
                        label: 'Edit',
                        onPressed: () {
                          Navigator.pop(sheet);
                          showEditTransactionSheet(context, ref, t);
                        },
                      ),
                    ),
                  ],
                ),
            ],
          ),
          ),
        ),
      );
    },
  );
}

/// Quick labels. The user can also type their own.
const _labels = ['Friend', 'Family', 'Rent', 'Lent', 'Borrowed', 'Gift', 'Work', 'Trip', 'One-time'];

/// The edit form as a bottom sheet. Completes when the sheet is closed.
Future<void> showEditTransactionSheet(BuildContext context, WidgetRef ref, Txn t, {bool focusNote = false}) {
  final messenger = ScaffoldMessenger.of(context);
  final merchant = TextEditingController(text: t.merchant);
  final amount = TextEditingController(
      text: t.amount == t.amount.roundToDouble()
          ? t.amount.toInt().toString()
          : t.amount.toString());
  final label = TextEditingController(text: t.label ?? '');
  final note = TextEditingController(text: t.note ?? '');
  var category = t.category.name;
  var method = t.mode; // only changeable for entries made by hand
  var date = t.date;
  var busy = false;
  var applyAll = false; // also move the other payments to this merchant
  final cats = t.isIncome ? incomeCategories : expenseCategories;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true, // stays below the status bar
    backgroundColor: Colors.white,
    shape: _shape,
    builder: (sheet) => StatefulBuilder(
      builder: (_, setS) {
        Widget title(String text) => Padding(
              padding: const EdgeInsets.only(top: 18, bottom: 8),
              child: Text(text,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.dark50)),
            );

        Widget chip(String text, bool selected, VoidCallback onTap) => ChoiceChip(
              label: Text(text, style: TextStyle(fontSize: 13, color: selected ? AppColors.violet100 : AppColors.dark50)),
              selected: selected,
              onSelected: (_) => onTap(),
              showCheckmark: false,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              selectedColor: AppColors.violet20,
              backgroundColor: Colors.grey.withOpacity(0.08),
              side: BorderSide(color: selected ? AppColors.violet100 : Colors.transparent),
            );

        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheet).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // header: handle, title, close
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Edit ${t.isIncome ? 'income' : 'expense'}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    ),
                    IconButton(
                        onPressed: () => Navigator.pop(sheet), icon: const Icon(Icons.close)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      title('Amount and date'),
                      Row(
                        children: [
                          Expanded(
                            flex: 5,
                            child: TextField(
                              controller: amount,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                              decoration: const InputDecoration(
                                  prefixText: '₹ ', isDense: true, border: OutlineInputBorder()),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 6,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(48),
                                  padding: const EdgeInsets.symmetric(horizontal: 8)),
                              icon: const Icon(Icons.calendar_today, size: 16),
                              label: Text('${shortDate(date)} ${date.year}', maxLines: 1),
                              onPressed: () async {
                                final d = await pickDateSheet(
                                  sheet,
                                  initial: date,
                                  first: DateTime(2000),
                                  last: DateTime.now().add(const Duration(days: 1)),
                                );
                                if (d != null) setS(() => date = d);
                              },
                            ),
                          ),
                        ],
                      ),
                      title('Name'),
                      TextField(
                        controller: merchant,
                        decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                      ),
                      title('Category'),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final c in cats)
                            chip(c.name, category == c.name, () => setS(() => category = c.name)),
                        ],
                      ),
                      if (category != t.category.name)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: AppColors.violet100,
                          title: Text('Move every ${t.merchant} payment to $category',
                              style: const TextStyle(fontSize: 13)),
                          value: applyAll,
                          onChanged: (v) => setS(() => applyAll = v ?? false),
                        ),
                      if (t.statementId == null) ...[
                        title('Paid via'),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final m in methodsFor(isIncome: t.isIncome, isTransfer: t.category.name == 'Transfer'))
                              chip(m.mode, method == m.mode, () => setS(() => method = m.mode)),
                          ],
                        ),
                        if (!methodInBank(method))
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text('Not on a bank statement, so it does not change your bank balance.',
                                style: TextStyle(color: Colors.grey[600], fontSize: 12.5)),
                          ),
                      ],
                      title('Label'),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final l in _labels)
                            chip(l, label.text == l, () => setS(() => label.text = label.text == l ? '' : l)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: label,
                        maxLength: 40,
                        onChanged: (_) => setS(() {}),
                        decoration: const InputDecoration(
                            hintText: 'Or type your own label',
                            counterText: '',
                            isDense: true,
                            border: OutlineInputBorder()),
                      ),
                      title('Note'),
                      TextField(
                        controller: note,
                        autofocus: focusNote,
                        minLines: 2,
                        maxLines: 4,
                        maxLength: 500,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                            hintText: 'e.g. Lent for a bus ticket, returns Friday',
                            border: OutlineInputBorder()),
                      ),
                    ],
                  ),
                ),
              ),
              // Save stays in view while the form scrolls
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: SafeArea(
                  top: false,
                  child: SolidButtonWidget(
                    label: busy ? 'Saving...' : 'Save',
                    onPressed: busy
                        ? null
                        : () async {
                            final amt = double.tryParse(amount.text.trim());
                            if (amt == null || amt <= 0 || merchant.text.trim().isEmpty) {
                              messenger.showSnackBar(const SnackBar(
                                  content: Text('Enter an amount and a name')));
                              return;
                            }
                            setS(() => busy = true);
                            try {
                              var moved = 0;
                              if (applyAll && category != t.category.name) {
                                moved = await ref
                                    .read(ledgerProvider.notifier)
                                    .recategorize(t.merchant, category, t.isIncome);
                              }
                              await ref.read(ledgerProvider.notifier).edit(
                                    t.id!,
                                    Txn(
                                      date: DateTime(date.year, date.month, date.day),
                                      merchant: merchant.text.trim(),
                                      mode: method,
                                      category: categoryByName(category),
                                      amount: amt,
                                      isIncome: t.isIncome,
                                      note: note.text.trim().isEmpty ? null : note.text.trim(),
                                      label: label.text.trim().isEmpty ? null : label.text.trim(),
                                    ),
                                  );
                              if (sheet.mounted) Navigator.pop(sheet);
                              messenger.showSnackBar(SnackBar(
                                  content: Text(moved > 1
                                      ? '$moved ${t.merchant} payments moved to $category'
                                      : 'Transaction updated')));
                            } catch (e) {
                              if (sheet.mounted) setS(() => busy = false);
                              messenger.showSnackBar(SnackBar(content: Text(_err(e))));
                            }
                          },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
