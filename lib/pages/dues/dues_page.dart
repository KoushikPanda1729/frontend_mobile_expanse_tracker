import 'package:expensetracker/commons/components/sheets/app_sheets.dart';
import 'package:expensetracker/commons/constants/app_colors.dart';
import 'package:expensetracker/data/api.dart';
import 'package:expensetracker/data/dues.dart';
import 'package:expensetracker/data/ledger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// A notebook of money to get and money to give. Kept apart from the transactions on purpose.
class DuesPage extends ConsumerStatefulWidget {
  const DuesPage({super.key});

  @override
  ConsumerState<DuesPage> createState() => _DuesPageState();
}

class _DuesPageState extends ConsumerState<DuesPage> {
  int _tab = 0; // 0 all, 1 to get, 2 to give

  String _d(DateTime d) => '${shortDate(d)} ${d.year}';
  String _err(Object e) => e is ApiException ? e.message : 'Something went wrong.';
  void _say(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  Future<void> _reload() async => ref.refresh(duesProvider.future);

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(duesProvider);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.dark100,
        centerTitle: true,
        title: const Text('Money to get & pay', style: TextStyle(fontWeight: FontWeight.w700)),
        leading: BackButton(onPressed: () => context.canPop() ? context.pop() : context.go('/')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.violet100,
        foregroundColor: Colors.white,
        onPressed: () => _form(),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Could not load\n${_err(e)}', textAlign: TextAlign.center),
            TextButton(onPressed: () => ref.invalidate(duesProvider), child: const Text('Retry')),
          ]),
        ),
        data: (d) => RefreshIndicator(
          color: AppColors.violet100,
          onRefresh: _reload,
          child: _list(d),
        ),
      ),
    );
  }

  Widget _list(DuesData d) {
    bool show(Due x) => _tab == 0 || (_tab == 1 ? x.toGet : !x.toGet);
    final open = d.items.where((x) => x.isOpen && show(x)).toList();
    final settled = d.items.where((x) => !x.isOpen && show(x)).toList();
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
      children: [
        _summary(d),
        const SizedBox(height: 16),
        _tabs(),
        const SizedBox(height: 12),
        if (open.isEmpty && settled.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 60),
            child: Column(children: [
              const Icon(Icons.handshake_outlined, size: 52, color: AppColors.violet100),
              const SizedBox(height: 12),
              const Text('Nothing here yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('Note who will pay you and who you need to pay.\nIt stays separate from your transactions.',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], height: 1.4)),
            ]),
          ),
        for (final x in open) _card(x),
        if (settled.isNotEmpty)
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('Settled (${settled.length})',
                  style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w700)),
              children: [for (final x in settled) _card(x)],
            ),
          ),
      ],
    );
  }

  Widget _summary(DuesData d) {
    final net = d.toGet - d.toGive;
    Widget tile(String label, double v, IconData icon) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.16), borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(icon, size: 16, color: Colors.white70),
                const SizedBox(width: 6),
                Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
              ]),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(inr(v),
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
              ),
            ]),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.violet80, AppColors.violet100]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          tile('You will get', d.toGet, Icons.south_west),
          const SizedBox(width: 12),
          tile('You need to pay', d.toGive, Icons.north_east),
        ]),
        const SizedBox(height: 12),
        Text(
          net == 0
              ? 'All square'
              : net > 0
                  ? 'Overall, you will get ${inr(net)}'
                  : 'Overall, you need to pay ${inr(-net)}',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ]),
    );
  }

  Widget _tabs() {
    const labels = ['All', 'To get', 'To pay'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        for (var i = 0; i < 3; i++)
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tab = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: i == _tab ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(labels[i],
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: i == _tab ? AppColors.violet100 : AppColors.dark25)),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _card(Due x) {
    final color = x.toGet ? AppColors.green100 : AppColors.red100;
    final partly = x.settled > 0 && x.isOpen;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.grey.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _detail(x),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: color.withOpacity(0.14),
                child: Text(x.person[0].toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(x.person, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(x.toGet ? 'will pay you' : 'you need to pay',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12.5)),
                  if (x.note != null) Text(x.note!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[600], fontSize: 12.5)),
                  if (x.dueDate != null && x.isOpen)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: (x.overdue ? AppColors.red100 : AppColors.violet100).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(x.overdue ? 'Overdue · ${_d(x.dueDate!)}' : 'Due ${_d(x.dueDate!)}',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: x.overdue ? AppColors.red100 : AppColors.violet100)),
                      ),
                    ),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(x.isOpen ? inr(x.remaining) : 'Settled',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: x.isOpen ? color : Colors.grey)),
                if (partly) Text('of ${inr(x.amount)}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  // ---------- one entry: details and what you can do ----------

  void _detail(Due x) {
    final color = x.toGet ? AppColors.green100 : AppColors.red100;
    showAppSheet<void>(
      context: context,
      builder: (sheet) => SheetFrame(
        title: Text(x.person),
        content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(x.toGet ? 'will pay you' : 'you need to pay', style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 4),
          Text(inr(x.remaining), style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: x.isOpen ? color : Colors.grey)),
          if (x.settled > 0) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: (x.settled / x.amount).clamp(0.0, 1.0), minHeight: 8, color: color, backgroundColor: color.withOpacity(0.15)),
            ),
            const SizedBox(height: 6),
            Text('${inr(x.settled)} paid back of ${inr(x.amount)}', style: TextStyle(color: Colors.grey[700], fontSize: 13)),
          ] else
            Text('Total ${inr(x.amount)}', style: TextStyle(color: Colors.grey[700], fontSize: 13)),
          if (x.dueDate != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Due ${_d(x.dueDate!)}', style: TextStyle(color: x.overdue ? AppColors.red100 : Colors.grey[700], fontSize: 13))),
          if (x.note != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(x.note!, style: const TextStyle(height: 1.4))),
          const SizedBox(height: 16),
          if (x.isOpen) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.violet100, minimumSize: const Size.fromHeight(48)),
                onPressed: () {
                  Navigator.pop(sheet);
                  _recordPayment(x);
                },
                icon: const Icon(Icons.payments_outlined, size: 18),
                label: Text(x.toGet ? 'Record money received' : 'Record money paid'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                onPressed: () async {
                  Navigator.pop(sheet);
                  await _run(() => settleDue(x.id, x.remaining), 'Marked as settled');
                },
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Mark fully settled'),
              ),
            ),
          ],
          Row(children: [
            Expanded(
              child: TextButton.icon(
                onPressed: () {
                  Navigator.pop(sheet);
                  _form(edit: x);
                },
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit'),
              ),
            ),
            Expanded(
              child: TextButton.icon(
                onPressed: () async {
                  Navigator.pop(sheet);
                  final ok = await confirmSheet(context,
                      title: 'Delete this entry?', message: '${x.person}, ${inr(x.amount)} will be removed.', confirmLabel: 'Delete', destructive: true);
                  if (ok) await _run(() => deleteDue(x.id), 'Deleted');
                },
                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.red100),
                label: const Text('Delete', style: TextStyle(color: AppColors.red100)),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  bool _working = false; // one request at a time: a repeated tap is ignored until the first finishes

  Future<void> _run(Future<void> Function() job, String done) async {
    if (_working) return;
    _working = true;
    try {
      await job();
      ref.invalidate(duesProvider);
      if (mounted) _say(done);
    } catch (e) {
      if (mounted) _say(_err(e));
    } finally {
      _working = false;
    }
  }

  void _recordPayment(Due x) {
    final amount = TextEditingController(text: x.remaining == x.remaining.roundToDouble() ? x.remaining.toInt().toString() : x.remaining.toString());
    showAppSheet<void>(
      context: context,
      builder: (sheet) => SheetFrame(
        title: Text(x.toGet ? 'Money received from ${x.person}' : 'Money paid to ${x.person}'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: SheetField(
            label: 'Amount',
            controller: amount,
            autofocus: true,
            prefix: '₹ ',
            helper: 'Still open: ${inr(x.remaining)}',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(sheet), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.violet100),
            onPressed: () async {
              final v = double.tryParse(amount.text.trim());
              if (v == null || v <= 0) return;
              Navigator.pop(sheet);
              await _run(() => settleDue(x.id, v), 'Saved');
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  /// Add (edit == null) or change an entry.
  void _form({Due? edit}) {
    var toGet = edit?.toGet ?? true;
    final person = TextEditingController(text: edit?.person ?? '');
    final amount = TextEditingController(text: edit == null ? '' : (edit.amount == edit.amount.roundToDouble() ? edit.amount.toInt().toString() : edit.amount.toString()));
    final note = TextEditingController(text: edit?.note ?? '');
    DateTime? due = edit?.dueDate;
    showAppSheet<void>(
      context: context,
      builder: (sheet) => StatefulBuilder(
        builder: (_, setS) => SheetFrame(
          title: Text(edit == null ? 'New entry' : 'Edit entry'),
          content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 10),
            SheetChoice(
              options: const [('I will get', AppColors.green100), ('I need to pay', AppColors.red100)],
              selected: toGet ? 0 : 1,
              onSelected: (i) => setS(() => toGet = i == 0),
            ),
            const SizedBox(height: 18),
            SheetField(
              label: toGet ? 'Who will pay you?' : 'Who do you need to pay?',
              controller: person,
              hint: 'Name',
              capitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            SheetField(
              label: 'How much?',
              controller: amount,
              hint: '0',
              prefix: '₹ ',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            ),
            const SizedBox(height: 16),
            const Text('Due date (optional)',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.dark50)),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final d = await pickDateSheet(sheet,
                        initial: due ?? DateTime.now(), first: DateTime(2020), last: DateTime.now().add(const Duration(days: 365 * 5)), title: 'Due date');
                    if (d != null) setS(() => due = d);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                    decoration: BoxDecoration(color: const Color(0xFFF4F4F8), borderRadius: BorderRadius.circular(14)),
                    child: Row(children: [
                      const Icon(Icons.event_outlined, size: 20, color: AppColors.violet100),
                      const SizedBox(width: 10),
                      Text(due == null ? 'Pick a date' : _d(due!),
                          style: TextStyle(fontSize: 16, fontWeight: due == null ? FontWeight.w400 : FontWeight.w600, color: due == null ? Colors.grey[500] : AppColors.dark100)),
                    ]),
                  ),
                ),
              ),
              if (due != null) IconButton(onPressed: () => setS(() => due = null), icon: const Icon(Icons.close)),
            ]),
            const SizedBox(height: 16),
            SheetField(
              label: 'Note (optional)',
              controller: note,
              hint: 'e.g. bike repair, lunch',
              minLines: 2,
              maxLines: 3,
              maxLength: 300,
              capitalization: TextCapitalization.sentences,
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(sheet), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.violet100, minimumSize: const Size(96, 46)),
              onPressed: () async {
                final v = double.tryParse(amount.text.trim());
                if (person.text.trim().isEmpty || v == null || v <= 0) {
                  _say('Enter a name and an amount');
                  return;
                }
                Navigator.pop(sheet);
                await _run(
                  () => edit == null
                      ? addDue(person: person.text.trim(), toGet: toGet, amount: v, note: note.text.trim(), dueDate: due)
                      : updateDue(edit.id, person: person.text.trim(), toGet: toGet, amount: v, note: note.text.trim(), dueDate: due),
                  edit == null ? 'Added' : 'Saved',
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
