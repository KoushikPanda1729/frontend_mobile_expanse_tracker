import 'package:expensetracker/commons/components/button/app/solid_button_widget.dart';
import 'package:expensetracker/commons/constants/app_colors.dart';
import 'package:expensetracker/data/api.dart';
import 'package:expensetracker/data/ledger.dart';
import 'package:expensetracker/pages/review/review_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
              const SizedBox(height: 16),
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
                          final ok = await showDialog<bool>(
                            context: sheet,
                            builder: (d) => AlertDialog(
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
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SolidButtonWidget(
                        label: 'Edit',
                        onPressed: () {
                          Navigator.pop(sheet);
                          _showEditSheet(context, ref, t);
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

void _showEditSheet(BuildContext context, WidgetRef ref, Txn t) {
  final messenger = ScaffoldMessenger.of(context);
  final merchant = TextEditingController(text: t.merchant);
  final amount = TextEditingController(
      text: t.amount == t.amount.roundToDouble()
          ? t.amount.toInt().toString()
          : t.amount.toString());
  var category = t.category.name;
  var date = t.date;
  var busy = false;
  var applyAll = false; // also move the other payments to this merchant
  final cats = t.isIncome ? incomeCategories : expenseCategories;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: _shape,
    builder: (sheet) => StatefulBuilder(
      builder: (_, setS) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 20, 16, 16 + MediaQuery.of(sheet).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Edit ${t.isIncome ? 'income' : 'expense'}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              TextField(
                controller: amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                ],
                decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: '₹ ',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: merchant,
                decoration: const InputDecoration(
                    labelText: 'Merchant / note', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in cats)
                    ChoiceChip(
                      label: Text(c.name),
                      selected: category == c.name,
                      onSelected: (_) => setS(() => category = c.name),
                    ),
                ],
              ),
              if (category != t.category.name)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: AppColors.violet100,
                  title: Text('Move every ${t.merchant} payment to $category'),
                  value: applyAll,
                  onChanged: (v) => setS(() => applyAll = v ?? false),
                ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text('${shortDate(date)} ${date.year}'),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: sheet,
                    initialDate: date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now().add(const Duration(days: 1)),
                  );
                  if (d != null) setS(() => date = d);
                },
              ),
              const SizedBox(height: 20),
              SolidButtonWidget(
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
                                  mode: t.mode,
                                  category: categoryByName(category),
                                  amount: amt,
                                  isIncome: t.isIncome,
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
            ],
          ),
        ),
      ),
    ),
  );
}
