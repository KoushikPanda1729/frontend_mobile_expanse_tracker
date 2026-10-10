import 'package:expensetracker/commons/components/button/app/solid_button_widget.dart';
import 'package:expensetracker/commons/components/sheets/app_sheets.dart';
import 'package:expensetracker/commons/components/notification_bar/notification_bar.dart';
import 'package:expensetracker/commons/components/text_field/app/views/alpha_neumeric_textfield_widget.dart';
import 'package:expensetracker/commons/constants/app_colors.dart';
import 'package:expensetracker/commons/constants/app_icons.dart';
import 'package:expensetracker/data/api.dart';
import 'package:expensetracker/data/ledger.dart';
import 'package:expensetracker/data/payment_methods.dart';
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
  late String _method = _methods.first.mode; // UPI, Card, Net banking, Cash, ...
  String? _tag; // optional tag: Friend, Rent, ...
  final _memo = TextEditingController(); // optional note
  DateTime _date = DateTime.now();
  // payees the user already labelled ("I know this payee"): their category is filled in when the name matches
  final Map<String, ({String category, String? label})> _rules = {};
  String? _ruleHint;

  List<PayMethod> get _methods => methodsFor(
      isIncome: widget.kind == TxnKind.income, isTransfer: widget.kind == TxnKind.transfer);

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
  void initState() {
    super.initState();
    _loadRules();
  }

  Future<void> _loadRules() async {
    try {
      final j = await api.get('/payees') as Map<String, dynamic>;
      for (final r in j['items'] as List) {
        final m = r as Map<String, dynamic>;
        _rules[(m['merchant'] as String).trim().toLowerCase()] =
            (category: m['category'] as String, label: m['label'] as String?);
      }
    } catch (_) {} // offline: no suggestions
  }

  /// Typing a name you already labelled picks its category.
  void _onName(String v) {
    _note = v;
    final r = _rules[v.trim().toLowerCase()];
    if (r != null && _cats.any((c) => c.name == r.category)) {
      setState(() {
        _category = r.category;
        _ruleHint = 'Using your saved category for ${v.trim()}';
      });
    } else if (_ruleHint != null) {
      setState(() => _ruleHint = null);
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _memo.dispose();
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
            // Cash and Wallet are never on a bank statement, so the import does not try to match them
            mode: _method,
            category: cat,
            amount: amt,
            isIncome: widget.kind == TxnKind.income,
            label: _tag ?? (isTransfer ? null : _rules[_note.trim().toLowerCase()]?.label),
            note: _memo.text.trim().isEmpty ? null : _memo.text.trim(),
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
    final d = await pickDateSheet(
      context,
      initial: _date,
      first: DateTime(2020),
      last: DateTime.now(),
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
                                hintText: 'e.g. Arjun, a friend',
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
                                          _category == c.name ? Colors.white : c.color,
                                          BlendMode.srcIn,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              _label(widget.kind == TxnKind.income ? 'Received from' : 'Paid to'),
                              AlphaNumericTextfieldWidget(
                                onTextChanged: _onName,
                                labelText: '',
                                hintText: widget.kind == TxnKind.income
                                    ? 'e.g. employer, a friend'
                                    : 'e.g. Zomato, grocery shop, Ramesh',
                              ),
                              if (_ruleHint != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.check_circle, size: 14, color: AppColors.violet100),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(_ruleHint!,
                                            style: TextStyle(color: Colors.grey[700], fontSize: 12.5)),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                            _label('Date'),
                            Wrap(
                              spacing: 8,
                              children: [
                                _chip('Today', _isToday, () => setState(() => _date = DateTime.now())),
                                _chip('Yesterday', _isYesterday,
                                    () => setState(() => _date = DateTime.now().subtract(const Duration(days: 1)))),
                                _chip(
                                  _isToday || _isYesterday ? 'Pick date' : '${shortDate(_date)} ${_date.year}',
                                  !(_isToday || _isYesterday),
                                  _pickDate,
                                  leading: Icon(
                                    Icons.calendar_today_outlined,
                                    size: 14,
                                    color: !(_isToday || _isYesterday) ? Colors.white : AppColors.dark50,
                                  ),
                                ),
                              ],
                            ),
                            _label(switch (widget.kind) {
                              TxnKind.income => 'Received via',
                              TxnKind.transfer => 'Transferred via',
                              TxnKind.expense => 'Paid via',
                            }),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final m in _methods)
                                  _chip(
                                    m.mode,
                                    _method == m.mode,
                                    () => setState(() => _method = m.mode),
                                    leading: Icon(m.icon,
                                        size: 15, color: _method == m.mode ? Colors.white : AppColors.dark50),
                                  ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                methodInBank(_method)
                                    ? 'Shows on your bank statement, so it is matched when you import it.'
                                    : 'Not on a bank statement, so it is never matched, and it does not change your bank balance.',
                                style: TextStyle(color: Colors.grey[600], fontSize: 12.5, height: 1.35),
                              ),
                            ),
                            _label('Tag (optional)'),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final t in txnTags)
                                  _chip(t, _tag == t, () => setState(() => _tag = _tag == t ? null : t)),
                              ],
                            ),
                            _label('Note (optional)'),
                            TextField(
                              controller: _memo,
                              minLines: 1,
                              maxLines: 3,
                              maxLength: 500,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: InputDecoration(
                                hintText: 'e.g. lent for a bus ticket, returns Friday',
                                counterText: '',
                                filled: true,
                                fillColor: Colors.grey.withOpacity(0.06),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                              ),
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
