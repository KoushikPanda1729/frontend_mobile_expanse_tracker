import 'package:expensetracker/commons/components/button/app/solid_button_widget.dart';
import 'package:expensetracker/commons/components/notification_bar/notification_bar.dart';
import 'package:expensetracker/commons/components/text_field/app/views/alpha_neumeric_textfield_widget.dart';
import 'package:expensetracker/commons/constants/app_colors.dart';
import 'package:expensetracker/commons/constants/app_icons.dart';
import 'package:expensetracker/data/api.dart';
import 'package:expensetracker/data/ledger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

enum TxnKind { income, expense, transfer }

/// One form for Income, Expense and Transfer (transfer is saved as an expense).
class AddTransactionPage extends ConsumerStatefulWidget {
  final TxnKind kind;
  const AddTransactionPage({super.key, required this.kind});

  @override
  ConsumerState<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends ConsumerState<AddTransactionPage> {
  final _amount = TextEditingController();
  String _note = '', _to = '';
  late String _category = _cats.first.name;
  String _account = 'Account';
  DateTime _date = DateTime.now();

  List<Category> get _cats =>
      widget.kind == TxnKind.income ? incomeCategories : expenseCategories;

  Color get _bg => switch (widget.kind) {
        TxnKind.income => AppColors.green100,
        TxnKind.expense => AppColors.red100,
        TxnKind.transfer => AppColors.blue100,
      };

  String get _title => switch (widget.kind) {
        TxnKind.income => 'Income',
        TxnKind.expense => 'Expense',
        TxnKind.transfer => 'Transfer',
      };

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
  bool get _isToday => _day(_date) == _day(DateTime.now());
  bool get _isYesterday =>
      _day(_date) == _day(DateTime.now().subtract(const Duration(days: 1)));

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _addQuick(int v) {
    final cur = double.tryParse(_amount.text.trim()) ?? 0;
    final n = cur + v;
    _amount.text = n == n.roundToDouble() ? n.toInt().toString() : n.toString();
    _amount.selection = TextSelection.collapsed(offset: _amount.text.length);
    setState(() {});
  }

  Future<void> _save() async {
    final amt = double.tryParse(_amount.text.trim());
    final messenger = ScaffoldMessenger.of(context);
    if (amt == null || amt <= 0) {
      messenger.showSnackBar(const SnackBar(content: Text('Enter an amount')));
      return;
    }
    final isTransfer = widget.kind == TxnKind.transfer;
    final cat = isTransfer ? categoryByName('Transfer') : categoryByName(_category);
    final who = isTransfer ? _to : _note;
    try {
      await ref.read(ledgerProvider.notifier).add(Txn(
            date: _day(_date),
            merchant: who.trim().isEmpty ? cat.name : who.trim(),
            mode: 'Manual',
            category: cat,
            amount: amt,
            isIncome: widget.kind == TxnKind.income,
          ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text(e is ApiException ? e.message : 'Could not save.')));
      return;
    }
    if (!mounted) return;
    ref.read(monthProvider.notifier).state = Ledger.keyOf(_date);
    context.pop();
    messenger.showSnackBar(SnackBar(content: Text('$_title of ${inr(amt)} saved')));
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2025),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _date = d);
  }

  // ---------- small UI helpers ----------

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 16),
        child: Text(t,
            style: TextStyle(
                color: Colors.grey[700],
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      );

  Widget _chip(String text, bool sel, VoidCallback onTap,
      {Widget? leading, Color? selColor}) {
    final on = selColor ?? _bg;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: sel ? on : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[leading, const SizedBox(width: 6)],
            Text(text,
                style: TextStyle(
                    color: sel ? Colors.white : AppColors.dark50,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTransfer = widget.kind == TxnKind.transfer;
    return Scaffold(
      backgroundColor: _bg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: NotificationBar(
                isPrifileVisible: false,
                title: _title,
                leadingIcon: AppIcons.arrowLeftIcon,
                isTrailingIcon: false,
                labelColor: Colors.white,
                onTap: () => context.canPop() ? context.pop() : context.go('/'),
              ),
            ),
            // amount
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Column(
                children: [
                  const Text('How much?',
                      style: TextStyle(color: Colors.white70, fontSize: 15)),
                  TextField(
                    controller: _amount,
                    textAlign: TextAlign.center,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))
                    ],
                    cursorColor: Colors.white,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 54,
                        fontWeight: FontWeight.w700),
                    decoration: const InputDecoration(
                      prefixText: '₹',
                      prefixStyle: TextStyle(
                          color: Colors.white,
                          fontSize: 54,
                          fontWeight: FontWeight.w700),
                      hintText: '0',
                      hintStyle: TextStyle(color: Colors.white54),
                      border: InputBorder.none,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final v in const [100, 500, 1000, 5000])
                        GestureDetector(
                          onTap: () => _addQuick(v),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text('+${inr(v.toDouble())}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            // form sheet fills the rest of the screen, down to the bottom edge
            Expanded(
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                    16, 4, 16, 12 + MediaQuery.of(context).padding.bottom),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isTransfer) ...[
                              _label('Transfer to'),
                              AlphaNumericTextfieldWidget(
                                onTextChanged: (v) => _to = v,
                                labelText: '',
                                hintText: 'e.g. Arjun',
                              ),
                            ] else ...[
                              _label('Category'),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final c in _cats)
                                    _chip(
                                      c.name,
                                      _category == c.name,
                                      () => setState(() => _category = c.name),
                                      leading: SvgPicture.asset(
                                        c.icon,
                                        width: 15,
                                        height: 15,
                                        colorFilter: ColorFilter.mode(
                                          _category == c.name
                                              ? Colors.white
                                              : c.color,
                                          BlendMode.srcIn,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              _label('Description'),
                              AlphaNumericTextfieldWidget(
                                onTextChanged: (v) => _note = v,
                                labelText: '',
                                hintText: widget.kind == TxnKind.income
                                    ? 'e.g. salary, from a friend'
                                    : 'e.g. lunch, recharge',
                              ),
                            ],
                            _label('Date'),
                            Wrap(
                              spacing: 8,
                              children: [
                                _chip('Today', _isToday,
                                    () => setState(() => _date = DateTime.now())),
                                _chip(
                                    'Yesterday',
                                    _isYesterday,
                                    () => setState(() => _date = DateTime.now()
                                        .subtract(const Duration(days: 1)))),
                                _chip(
                                  _isToday || _isYesterday
                                      ? 'Pick date'
                                      : '${shortDate(_date)} ${_date.year}',
                                  !(_isToday || _isYesterday),
                                  _pickDate,
                                  leading: Icon(
                                    Icons.calendar_today_outlined,
                                    size: 14,
                                    color: !(_isToday || _isYesterday)
                                        ? Colors.white
                                        : AppColors.dark50,
                                  ),
                                ),
                              ],
                            ),
                            _label('Account'),
                            Wrap(
                              spacing: 8,
                              children: [
                                for (final a in const ['Account', 'Wallet', 'Cash'])
                                  _chip(a, _account == a,
                                      () => setState(() => _account = a)),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SolidButtonWidget(label: 'Save $_title', onPressed: _save),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
