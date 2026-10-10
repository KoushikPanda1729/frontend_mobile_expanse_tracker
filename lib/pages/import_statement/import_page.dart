import 'package:dotted_border/dotted_border.dart';
import 'package:expensetracker/commons/components/button/app/solid_button_widget.dart';
import 'package:expensetracker/commons/components/transaction_card/app/transaction_card.dart';
import 'package:expensetracker/commons/constants/app_colors.dart';
import 'package:expensetracker/data/api.dart';
import 'package:expensetracker/data/ledger.dart';
import 'package:expensetracker/data/statement_import.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum _Step { pick, password, preview, done }

class ImportPage extends ConsumerStatefulWidget {
  const ImportPage({super.key});

  @override
  ConsumerState<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends ConsumerState<ImportPage> {
  _Step _step = _Step.pick;
  bool _busy = false;
  String? _error;
  PlatformFile? _file;
  StatementPreview? _found;
  String? _typedPassword; // the typed password that opened the file, if any
  bool _remember = false; // save the typed password for next time
  final Set<String> _accepted = {}; // manualIds the user wants merged
  final Set<String> _applyIds = {}; // transactions where the user takes the bank's version
  int _added = 0, _skipped = 0, _merged = 0, _applied = 0;
  final _pw = TextEditingController();

  @override
  void dispose() {
    _pw.dispose();
    super.dispose();
  }

  Future<void> _choose() async {
    setState(() => _error = null);
    try {
      final f = await pickStatementFile();
      if (f == null) return; // cancelled
      if (f.bytes == null) {
        setState(() => _error = 'Could not read that file.');
        return;
      }
      _file = f;
      _pw.clear();
      _remember = false;
      _read();
    } catch (e) {
      setState(() => _error = 'Could not open the file picker: $e');
    }
  }

  String _message(Object e, String fallback) =>
      e is ApiException ? e.message : fallback;

  /// Asks the server to read the PDF. A locked file is tried with the saved passwords first.
  Future<void> _read({String? password}) async {
    setState(() => _busy = true);
    try {
      final p = await previewStatement(_file!, password: password);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _found = p;
        // same-date matches start ticked, a day apart starts unticked: the user decides
        _accepted
          ..clear()
          ..addAll([for (final m in p.matches) if (m.daysApart == 0) m.manualId]);
        _applyIds.clear(); // nothing is overwritten unless the user ticks it
        _typedPassword = password;
        _step = _Step.preview;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (needsPdfPassword(e)) {
        final wrong = e is ApiException && e.code == 'PDF_PASSWORD_INCORRECT';
        setState(() {
          _busy = false;
          _step = _Step.password;
          _error = wrong ? 'Wrong password, try again.' : null;
        });
      } else {
        setState(() {
          _busy = false;
          _step = _Step.pick;
          _error = _message(e, 'Could not read this PDF.');
        });
      }
    }
  }

  Future<void> _confirm() async {
    setState(() => _busy = true);
    try {
      final r = await uploadStatement(_file!,
          password: _typedPassword,
          savePassword: _remember,
          merge: [for (final m in _found!.matches) if (_accepted.contains(m.manualId)) m],
          apply: _applyIds.toList());
      await ref.read(ledgerProvider.notifier).refresh();
      if (!mounted) return;
      ref.read(monthProvider.notifier).state = null;
      setState(() {
        _busy = false;
        _added = r.added;
        _skipped = r.skipped;
        _merged = r.merged;
        _applied = r.applied;
        _step = _Step.done;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_message(e, 'Import failed.'))));
    }
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.dark100,
        centerTitle: true,
        title: const Text('Import statement',
            style: TextStyle(fontWeight: FontWeight.w700)),
        leading: BackButton(
            onPressed: () => context.canPop() ? context.pop() : context.go('/')),
      ),
      body: SafeArea(
        child: switch (_step) {
          _Step.pick => _pick(),
          _Step.password => _password(),
          _Step.preview => _preview(),
          _Step.done => _done(),
        },
      ),
    );
  }

  Widget _badge(IconData icon, Color color) => Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
            color: color.withOpacity(0.12), shape: BoxShape.circle),
        child: Icon(icon, size: 40, color: color),
      );

  Widget _pick() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                const SizedBox(height: 12),
                DottedBorder(
                  color: AppColors.violet100.withOpacity(0.5),
                  strokeWidth: 1.5,
                  dashPattern: const [7, 5],
                  borderType: BorderType.RRect,
                  radius: const Radius.circular(24),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: _busy ? null : _choose,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 44),
                      decoration: BoxDecoration(
                        color: AppColors.violet20.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        children: [
                          _badge(Icons.upload_file, AppColors.violet100),
                          const SizedBox(height: 18),
                          const Text('Choose your statement PDF',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Text('Tap here to browse your files',
                              style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.red100.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppColors.red100, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(_error!,
                                style: const TextStyle(color: AppColors.red100))),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                const Text('How it works',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                _tip('1', 'Download your account statement as a PDF from your bank.'),
                _tip('2', 'Save it to Files on your phone.'),
                _tip('3', 'Choose it here and check the preview before importing.'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.lock_outline, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('The file is sent securely and stored encrypted on your account.',
                          style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SolidButtonWidget(
            label: _busy ? 'Reading...' : 'Choose PDF',
            onPressed: _busy ? null : _choose,
          ),
        ],
      ),
    );
  }

  Widget _tip(String n, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                  color: AppColors.violet20, shape: BoxShape.circle),
              child: Text(n,
                  style: const TextStyle(
                      color: AppColors.violet100,
                      fontWeight: FontWeight.w700,
                      fontSize: 12)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: const TextStyle(height: 1.35))),
          ],
        ),
      );

  Widget _password() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Center(child: _badge(Icons.lock_outline, AppColors.violet100)),
          const SizedBox(height: 20),
          const Center(
            child: Text('This PDF is password protected',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(_file?.name ?? '',
                style: TextStyle(color: Colors.grey[600]),
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _pw,
            obscureText: true,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'PDF password',
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (v) => _read(password: v),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: AppColors.violet100,
            title: const Text('Remember this password'),
            subtitle: const Text('Saved encrypted, so you do not type it again'),
            value: _remember,
            onChanged: (v) => setState(() => _remember = v ?? false),
          ),
          const Spacer(),
          SolidButtonWidget(
            label: _busy ? 'Unlocking...' : 'Unlock',
            onPressed: _busy ? null : () => _read(password: _pw.text),
          ),
          TextButton(
            onPressed: () => setState(() {
              _step = _Step.pick;
              _error = null;
            }),
            child: const Text('Choose a different file'),
          ),
        ],
      ),
    );
  }

  Widget _preview() {
    final p = _found!;
    final fresh = p.newCount;
    final dup = p.duplicateCount;
    final first = p.periodStart, last = p.periodEnd;
    String d(DateTime x) => '${shortDate(x)} ${x.year}';

    Widget stat(String label, String v, Color c) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.withOpacity(0.09),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(v,
                      style: TextStyle(
                          color: c, fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.violet80, AppColors.violet100],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.description_outlined,
                              color: Colors.white70, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_file?.name ?? '',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 13)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(p.alreadyUploaded ? 'Already imported' : '${p.count} transactions found',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('${d(first)}  -  ${d(last)}',
                          style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
                if (fresh > 0) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      stat('Income', inr(p.income), AppColors.green100),
                      const SizedBox(width: 10),
                      stat('Spent', inr(p.expense), AppColors.red100),
                      const SizedBox(width: 10),
                      stat('New', '$fresh', AppColors.violet100),
                    ],
                  ),
                ],
                if (fresh > 0 && dup > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text('$dup already in the app, they will be skipped.',
                        style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                  ),
                if (p.matches.isNotEmpty) _matches(p),
                if (p.changes.isNotEmpty) _changes(p),
                if (p.alreadyUploaded && p.changes.isEmpty && p.matches.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline, color: AppColors.green100),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text('Everything in this file already matches your data.',
                              style: TextStyle(color: Colors.grey[700])),
                        ),
                      ],
                    ),
                  ),
                if (fresh > 0) ...[
                const SizedBox(height: 20),
                const Text('Preview',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                for (final t in p.sample) ...[
                  TransactionCard(
                    icon: t.category.icon,
                    iconColor: t.category.color,
                    isIncome: t.isIncome,
                    title: t.merchant,
                    description: '${t.category.name} · ${shortDate(t.date)}',
                    amount: '${t.isIncome ? '+' : '-'} ${inr(t.amount)}',
                    onTap: () {},
                  ),
                  const SizedBox(height: 8),
                ],
                if (p.count > 5)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Center(
                      child: Text('and ${p.count - 5} more',
                          style: TextStyle(color: Colors.grey[600])),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SolidButtonWidget(
            label: _busy
                ? 'Importing...'
                : _applyIds.isNotEmpty && (p.alreadyUploaded || fresh == 0)
                    ? 'Apply ${_applyIds.length} change${_applyIds.length == 1 ? '' : 's'}'
                    : _applyIds.isNotEmpty
                        ? 'Import $fresh and apply ${_applyIds.length}'
                        : p.alreadyUploaded
                            ? 'Already uploaded'
                            : fresh == 0
                                ? 'Nothing new to import'
                                : 'Import $fresh transactions',
            onPressed: _busy || (_applyIds.isEmpty && (p.alreadyUploaded || fresh == 0)) ? null : _confirm,
          ),
          TextButton(
            onPressed: () => setState(() {
              _step = _Step.pick;
              _found = null;
            }),
            child: const Text('Choose a different file'),
          ),
        ],
      ),
    );
  }

  // ---------- decisions: tick = use the bank's version / merge, untick = keep as is ----------

  /// A card with a short title, one hint line, a select-all toggle and one row per decision.
  Widget _decisionCard({
    required IconData icon,
    required Color tint,
    required String title,
    required String hint,
    required int total,
    required Set<String> selected,
    required VoidCallback onToggleAll,
    required List<Widget> rows,
  }) {
    final all = selected.length == total;
    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tint.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      color: tint.withOpacity(0.14), shape: BoxShape.circle),
                  child: Icon(icon, size: 16, color: tint),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
                TextButton(
                  onPressed: onToggleAll,
                  child: Text(all ? 'Clear' : 'Select all'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
            child: Text(hint, style: TextStyle(color: Colors.grey[600], fontSize: 12.5)),
          ),
          for (final r in rows) ...[
            Divider(height: 1, color: Colors.grey.shade200),
            r,
          ],
        ],
      ),
    );
  }

  Widget _decisionRow({
    required bool ticked,
    required VoidCallback onTap,
    required Widget title,
    required List<Widget> lines,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: ticked ? AppColors.violet20.withOpacity(0.5) : null,
        padding: const EdgeInsets.fromLTRB(6, 8, 14, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: ticked,
              onChanged: (_) => onTap(),
              activeColor: AppColors.violet100,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 2),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [title, for (final l in lines) Padding(padding: const EdgeInsets.only(top: 5), child: l)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The row side by side: what you have vs what the bank says. Fields that differ are tinted and the
  /// bank's value is bold; fields that are the same stay grey so the difference is easy to spot.
  Widget _compare(StatementChange c) {
    String d(DateTime x) => '${const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][x.weekday - 1]}, ${shortDate(x)} ${x.year}';
    Widget cell(String text, {bool strike = false, bool strong = false, bool tint = false, Color? color}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: tint ? AppColors.yellow100.withOpacity(0.2) : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
              color: color ?? (strike ? Colors.grey[500] : Colors.grey[800]),
              decoration: strike ? TextDecoration.lineThrough : null,
            ),
          ),
        );
    TableRow line(String label, String yours, String bank, String field) {
      final changed = c.fields.contains(field);
      return TableRow(children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        ),
        cell(yours, strike: changed),
        cell(bank, strong: changed, tint: changed, color: changed ? AppColors.dark100 : Colors.grey[800]),
      ]);
    }

    final sign = c.isIncome ? '+ ' : '- ';
    return Table(
      columnWidths: const {0: FixedColumnWidth(66), 1: FlexColumnWidth(), 2: FlexColumnWidth()},
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(children: [
          const SizedBox.shrink(),
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 2),
            child: Text('You have', style: TextStyle(color: Colors.grey[600], fontSize: 11.5, fontWeight: FontWeight.w600)),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 2),
            child: Text('Bank says', style: TextStyle(color: AppColors.violet100, fontSize: 11.5, fontWeight: FontWeight.w700)),
          ),
        ]),
        line('Name', c.yoursName, c.bankName, 'name'),
        line('Amount', '$sign${inr(c.yoursAmount)}', '$sign${inr(c.bankAmount)}', 'amount'),
        line('Category', c.yoursCategory, c.bankCategory, 'category'),
        line('Date', d(c.yoursDate), d(c.bankDate), 'date'),
      ],
    );
  }

  Widget _chip(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
        child: Text(t, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w600)),
      );

  /// Rows you already have that differ from the file: tick to take the bank's version.
  Widget _changes(StatementPreview p) {
    final n = p.changes.length;
    return _decisionCard(
      icon: Icons.compare_arrows,
      tint: AppColors.yellow100,
      title: '$n change${n == 1 ? '' : 's'} from the bank',
      hint: "Tick to use the bank's version. Unticked rows stay as you have them.",
      total: n,
      selected: _applyIds,
      onToggleAll: () => setState(() {
        if (_applyIds.length == n) {
          _applyIds.clear();
        } else {
          _applyIds.addAll(p.changes.map((c) => c.id));
        }
      }),
      rows: [
        for (final c in p.changes)
          _decisionRow(
            ticked: _applyIds.contains(c.id),
            onTap: () => setState(() => _applyIds.contains(c.id) ? _applyIds.remove(c.id) : _applyIds.add(c.id)),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                      '${c.fields.map((f) => const {'name': 'Name', 'amount': 'Amount', 'category': 'Category', 'date': 'Date'}[f]).join(' and ')} ${c.fields.length == 1 ? 'differs' : 'differ'}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.violet100)),
                ),
              ],
            ),
            lines: [_compare(c)],
          ),
      ],
    );
  }

  /// Your own entries that look like bank rows: tick to merge them into one row.
  Widget _matches(StatementPreview p) {
    final n = p.matches.length;
    return _decisionCard(
      icon: Icons.link,
      tint: AppColors.violet100,
      title: '$n of your entr${n == 1 ? 'y matches a bank row' : 'ies match bank rows'}',
      hint: 'Tick to merge into one row. Unticked stay as two payments.',
      total: n,
      selected: _accepted,
      onToggleAll: () => setState(() {
        if (_accepted.length == n) {
          _accepted.clear();
        } else {
          _accepted.addAll(p.matches.map((m) => m.manualId));
        }
      }),
      rows: [
        for (final m in p.matches)
          _decisionRow(
            ticked: _accepted.contains(m.manualId),
            onTap: () => setState(() => _accepted.contains(m.manualId) ? _accepted.remove(m.manualId) : _accepted.add(m.manualId)),
            title: Row(
              children: [
                Expanded(
                  child: Text(m.manualName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                ),
                Text('${m.isIncome ? '+' : '-'} ${inr(m.amount)}',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: m.isIncome ? AppColors.green100 : AppColors.red100)),
              ],
            ),
            lines: [
              Text('You added ${shortDate(m.manualDate)}  ·  Bank: ${m.bankName}, ${shortDate(m.bankDate)}',
                  style: TextStyle(color: Colors.grey[700], fontSize: 12.5)),
              Wrap(
                spacing: 6,
                children: [
                  if (m.daysApart > 0) _chip('${m.daysApart} day apart', AppColors.yellow100),
                  if (m.label != null) _chip(m.label!, AppColors.violet100),
                  if (m.note != null) _chip('has note', AppColors.violet100),
                ],
              ),
            ],
          ),
      ],
    );
  }

  String _doneNote() {
    final parts = [
      if (_applied > 0 && _added > 0) '$_applied rows now follow the bank.',
      if (_merged > 0) '$_merged of your own entries were matched to the bank.',
      if (_skipped > 0) '$_skipped duplicates were skipped.',
    ];
    return parts.isEmpty ? 'Your data is ready.' : parts.join(' ');
  }

  Widget _done() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Spacer(flex: 2),
          _badge(Icons.check_circle_outline, AppColors.green100),
          const SizedBox(height: 22),
          Text(_added == 0 && _applied > 0 ? 'Updated $_applied transactions' : 'Imported $_added transactions',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            _doneNote(),
            style: TextStyle(color: Colors.grey[600]),
          ),
          const Spacer(flex: 3),
          SolidButtonWidget(
            label: 'See analysis',
            onPressed: () => context.pushReplacement('/analysis'),
          ),
          TextButton(
            onPressed: () => context.pushReplacement('/review'),
            child: const Text('Check payments you may not recognise'),
          ),
          TextButton(
            onPressed: () {
              ref.read(tabProvider.notifier).state = 1;
              context.go('/');
            },
            child: const Text('View transactions'),
          ),
        ],
      ),
    );
  }
}
