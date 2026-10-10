import 'package:expensetracker/commons/components/sheets/app_sheets.dart';
import 'package:expensetracker/commons/constants/app_colors.dart';
import 'package:expensetracker/data/api.dart';
import 'package:expensetracker/data/funds.dart';
import 'package:expensetracker/data/ledger.dart';
import 'package:expensetracker/pages/funds/funds_page.dart' show fundsSign;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// One mutual fund: what is in it, every payment, and what it is worth.
class FundDetailPage extends ConsumerStatefulWidget {
  final String id;
  const FundDetailPage({super.key, required this.id});

  @override
  ConsumerState<FundDetailPage> createState() => _FundDetailPageState();
}

class _FundDetailPageState extends ConsumerState<FundDetailPage> {
  String _d(DateTime d) => '${shortDate(d)} ${d.year}';
  String _err(Object e) => e is ApiException ? e.message : 'Something went wrong.';
  void _say(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  void _changed() {
    ref.invalidate(fundDetailProvider(widget.id));
    ref.invalidate(fundsProvider);
    ref.invalidate(unassignedProvider);
  }

  bool _working = false; // one request at a time: a repeated tap is ignored until the first finishes

  Future<void> _run(Future<void> Function() job, [String? done]) async {
    if (_working) return;
    _working = true;
    try {
      await job();
      _changed();
      if (done != null && mounted) _say(done);
    } catch (e) {
      if (mounted) _say(_err(e));
    } finally {
      _working = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(fundDetailProvider(widget.id));
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.dark100,
        centerTitle: true,
        title: Text(data.valueOrNull?.fund.name ?? 'Fund', overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        leading: BackButton(onPressed: () => context.canPop() ? context.pop() : context.go('/funds')),
        actions: [
          if (data.hasValue)
            IconButton(icon: const Icon(Icons.more_vert), onPressed: () => _menu(data.value!.fund)),
        ],
      ),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Could not load\n${_err(e)}', textAlign: TextAlign.center),
            TextButton(onPressed: () => ref.invalidate(fundDetailProvider(widget.id)), child: const Text('Retry')),
          ]),
        ),
        data: (d) => RefreshIndicator(
          color: AppColors.violet100,
          onRefresh: () async => ref.refresh(fundDetailProvider(widget.id).future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              _header(d.fund),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.violet100, minimumSize: const Size.fromHeight(48)),
                    onPressed: () => _entrySheet(withdraw: false),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add investment'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    onPressed: () => _entrySheet(withdraw: true),
                    icon: const Icon(Icons.remove, size: 18),
                    label: const Text('Withdraw'),
                  ),
                ),
              ]),
              const SizedBox(height: 22),
              Text('Payments (${d.entries.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              if (d.entries.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('No payments yet', style: TextStyle(color: Colors.grey[600]))),
                ),
              for (final e in d.entries) _entry(e),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(Fund f) {
    final gain = f.gain;
    Widget tile(String label, String v, {Color? color}) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.16), borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 3),
              FittedBox(fit: BoxFit.scaleDown, child: Text(v, style: TextStyle(color: color ?? Colors.white, fontSize: 17, fontWeight: FontWeight.w800))),
            ]),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.violet80, AppColors.violet100]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Invested', style: TextStyle(color: Colors.white70, fontSize: 14)),
        FittedBox(fit: BoxFit.scaleDown, child: Text(inr(f.netInvested), style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800))),
        if (f.withdrawn > 0)
          Text('${inr(f.invested)} in, ${inr(f.withdrawn)} taken out', style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
        const SizedBox(height: 12),
        Row(children: [
          tile('Worth now', f.currentValue == null ? 'Not set' : inr(f.currentValue!)),
          const SizedBox(width: 10),
          tile('Returns', gain == null ? '-' : '${fundsSign(gain)} ${inr(gain.abs())}${f.gainPercent == null ? '' : '  (${f.gainPercent}%)'}'),
        ]),
        const SizedBox(height: 10),
        InkWell(
          onTap: () => _valueSheet(f),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.edit_outlined, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                f.currentValue == null ? 'Add what it is worth today' : 'Update value${f.valueAsOf == null ? '' : ' (set ${_d(f.valueAsOf!)})'}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _entry(FundEntry e) {
    final color = e.withdraw ? AppColors.red100 : AppColors.green100;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
        decoration: BoxDecoration(color: Colors.grey.withOpacity(0.08), borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(e.withdraw ? Icons.south_west : Icons.north_east, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.withdraw ? 'Withdrawn' : 'Invested', style: const TextStyle(fontWeight: FontWeight.w700)),
              Text('${_d(e.date)}${e.note == null ? '' : '  ·  ${e.note}'}', style: TextStyle(color: Colors.grey[600], fontSize: 12.5)),
              if (e.fromStatement)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text('From your bank statement', style: TextStyle(color: AppColors.violet100, fontSize: 11.5, fontWeight: FontWeight.w600)),
                ),
            ]),
          ),
          Text('${e.withdraw ? '-' : '+'} ${inr(e.amount)}', style: TextStyle(fontWeight: FontWeight.w800, color: color)),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 20, color: Colors.grey[600]),
            onPressed: () async {
              final ok = await confirmSheet(context,
                  title: 'Remove this payment?',
                  message: e.fromStatement
                      ? 'It leaves this fund only. The bank transaction stays, and it can be added to a fund again.'
                      : '${inr(e.amount)} on ${_d(e.date)} will be removed.',
                  confirmLabel: 'Remove',
                  destructive: true);
              if (ok) await _run(() => deleteFundEntry(e.id), 'Removed');
            },
          ),
        ]),
      ),
    );
  }

  // ---------- sheets ----------

  void _entrySheet({required bool withdraw}) {
    var date = DateTime.now();
    final amount = TextEditingController();
    final note = TextEditingController();
    showAppSheet<void>(
      context: context,
      builder: (sheet) => StatefulBuilder(
        builder: (_, setS) => SheetFrame(
          title: Text(withdraw ? 'Money taken out' : 'Money put in'),
          content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 8),
            SheetField(
              label: 'How much?',
              controller: amount,
              autofocus: true,
              hint: '0',
              prefix: '₹ ',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            ),
            const SizedBox(height: 16),
            const Text('Date', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.dark50)),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () async {
                final d = await pickDateSheet(sheet, initial: date, first: DateTime(2000), last: DateTime.now());
                if (d != null) setS(() => date = d);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                decoration: BoxDecoration(color: const Color(0xFFF4F4F8), borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  const Icon(Icons.calendar_today, size: 18, color: AppColors.violet100),
                  const SizedBox(width: 10),
                  Text(_d(date), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(spacing: 8, children: [
              for (final t in const ['SIP', 'Lump sum', 'Top-up'])
                ActionChip(label: Text(t), onPressed: () => setS(() => note.text = t)),
            ]),
            const SizedBox(height: 8),
            SheetField(label: 'Note (optional)', controller: note, hint: 'e.g. monthly SIP'),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(sheet), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.violet100),
              onPressed: () async {
                final v = double.tryParse(amount.text.trim());
                if (v == null || v <= 0) return;
                Navigator.pop(sheet);
                await _run(() => addFundEntry(widget.id, date: date, amount: v, withdraw: withdraw, note: note.text.trim()), 'Saved');
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _valueSheet(Fund f) {
    final v = TextEditingController(text: f.currentValue == null ? '' : (f.currentValue! == f.currentValue!.roundToDouble() ? f.currentValue!.toInt().toString() : f.currentValue.toString()));
    showAppSheet<void>(
      context: context,
      builder: (sheet) => SheetFrame(
        title: const Text('What is it worth today?'),
        content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Look it up in your fund app (current value). Update it any time to keep your returns right.',
              style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.4)),
          const SizedBox(height: 14),
          SheetField(
            label: 'Current value',
            controller: v,
            autofocus: true,
            hint: '0',
            prefix: '₹ ',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          ),
        ]),
        actions: [
          if (f.currentValue != null)
            TextButton(
              onPressed: () async {
                Navigator.pop(sheet);
                await _run(() => setFundValue(widget.id, null), 'Value cleared');
              },
              child: const Text('Clear'),
            ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.violet100),
            onPressed: () async {
              final x = double.tryParse(v.text.trim());
              if (x == null) return;
              Navigator.pop(sheet);
              await _run(() => setFundValue(widget.id, x), 'Value saved');
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _menu(Fund f) {
    showAppSheet<void>(
      context: context,
      builder: (sheet) => SheetFrame(
        title: Text(f.name),
        content: Column(children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Rename'),
            onTap: () {
              Navigator.pop(sheet);
              _rename(f);
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.delete_outline, color: AppColors.red100),
            title: const Text('Delete fund', style: TextStyle(color: AppColors.red100)),
            onTap: () async {
              Navigator.pop(sheet);
              final ok = await confirmSheet(context,
                  title: 'Delete ${f.name}?',
                  message: 'The fund and its ${f.entryCount} payment${f.entryCount == 1 ? '' : 's'} are removed. Bank transactions are not touched.',
                  confirmLabel: 'Delete',
                  destructive: true);
              if (!ok) return;
              try {
                await deleteFund(widget.id);
                ref.invalidate(fundsProvider);
                ref.invalidate(unassignedProvider);
                if (mounted) context.go('/funds');
              } catch (e) {
                if (mounted) _say(_err(e));
              }
            },
          ),
        ]),
      ),
    );
  }

  void _rename(Fund f) {
    final c = TextEditingController(text: f.name);
    showAppSheet<void>(
      context: context,
      builder: (sheet) => SheetFrame(
        title: const Text('Rename fund'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: SheetField(label: 'Fund name', controller: c, autofocus: true, capitalization: TextCapitalization.words),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(sheet), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.violet100),
            onPressed: () async {
              if (c.text.trim().isEmpty) return;
              Navigator.pop(sheet);
              await _run(() => renameFund(widget.id, c.text.trim()), 'Renamed');
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
