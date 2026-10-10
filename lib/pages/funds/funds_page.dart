import 'package:expensetracker/commons/components/sheets/app_sheets.dart';
import 'package:expensetracker/commons/constants/app_colors.dart';
import 'package:expensetracker/data/api.dart';
import 'package:expensetracker/data/funds.dart';
import 'package:expensetracker/data/ledger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

String fundsSign(double v) => v >= 0 ? '+' : '-';

/// Your mutual funds: what each one is, how much went in, and (if you enter it) what it is worth.
class FundsPage extends ConsumerStatefulWidget {
  const FundsPage({super.key});

  @override
  ConsumerState<FundsPage> createState() => _FundsPageState();
}

class _FundsPageState extends ConsumerState<FundsPage> {
  String _err(Object e) => e is ApiException ? e.message : 'Something went wrong.';
  void _say(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _reload() async {
    ref.invalidate(unassignedProvider);
    ref.invalidate(fundsProvider);
    await ref.read(fundsProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(fundsProvider);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.dark100,
        centerTitle: true,
        title: const Text('Mutual funds', style: TextStyle(fontWeight: FontWeight.w700)),
        leading: BackButton(onPressed: () => context.canPop() ? context.pop() : context.go('/')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.violet100,
        foregroundColor: Colors.white,
        onPressed: _newFund,
        icon: const Icon(Icons.add),
        label: const Text('Add fund'),
      ),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Could not load\n${_err(e)}', textAlign: TextAlign.center),
            TextButton(onPressed: () => ref.invalidate(fundsProvider), child: const Text('Retry')),
          ]),
        ),
        data: (d) => RefreshIndicator(color: AppColors.violet100, onRefresh: _reload, child: _body(d)),
      ),
    );
  }

  Widget _body(FundsData d) {
    final un = ref.watch(unassignedProvider).valueOrNull ?? const <Unassigned>[];
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
      children: [
        _summary(d),
        if (un.isNotEmpty) _statementCard(un, d),
        const SizedBox(height: 18),
        if (d.items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 30),
            child: Column(children: [
              const Icon(Icons.trending_up, size: 52, color: AppColors.violet100),
              const SizedBox(height: 12),
              const Text('No funds yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('Add each mutual fund you hold, then the amounts you put in.',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], height: 1.4)),
            ]),
          ),
        for (final f in d.items) _fundCard(f),
      ],
    );
  }

  Widget _summary(FundsData d) {
    Widget tile(String label, String value, {Color? valueColor}) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.16), borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value, style: TextStyle(color: valueColor ?? Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              ),
            ]),
          ),
        );
    final gain = d.gain;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.violet80, AppColors.violet100]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('You have put in', style: TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(inr(d.netInvested), style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 12),
        Row(children: [
          tile('Worth now', d.currentValue == null ? '-' : inr(d.currentValue!)),
          const SizedBox(width: 10),
          tile('Returns', gain == null ? '-' : '${fundsSign(gain)} ${inr(gain.abs())}'),
        ]),
        const SizedBox(height: 10),
        Text(
          d.valuedFunds == 0
              ? 'Add what a fund is worth today to see your returns.'
              : 'Worth and returns count only the ${d.valuedFunds} fund${d.valuedFunds == 1 ? '' : 's'} you gave a value for.',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ]),
    );
  }

  /// Investment payments the bank statements show that are not in any fund yet.
  Widget _statementCard(List<Unassigned> un, FundsData d) {
    final total = un.fold(0.0, (a, x) => a + x.amount);
    return Container(
      margin: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(color: AppColors.yellow100.withOpacity(0.18), borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _assignSheet(un, d),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            const Icon(Icons.account_balance_outlined, color: AppColors.violet100),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${un.length} payment${un.length == 1 ? '' : 's'} from your statements',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('${inr(total)} looks like fund investing (Groww, SIP). Put it in a fund.',
                    style: TextStyle(color: Colors.grey[700], fontSize: 12.5, height: 1.3)),
              ]),
            ),
            const Icon(Icons.chevron_right, color: AppColors.violet100),
          ]),
        ),
      ),
    );
  }

  Widget _fundCard(Fund f) {
    final gain = f.gain;
    final up = (gain ?? 0) >= 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.grey.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => context.push('/funds/${f.id}'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(f.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                if (f.gainPercent != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: (up ? AppColors.green100 : AppColors.red100).withOpacity(0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${up ? '+' : ''}${f.gainPercent}%',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: up ? AppColors.green100 : AppColors.red100)),
                  ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                _stat('Invested', inr(f.netInvested)),
                _stat('Worth now', f.currentValue == null ? 'Not set' : inr(f.currentValue!)),
                _stat('Payments', '${f.entryCount}'),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, String v) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          const SizedBox(height: 2),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        ]),
      );

  // ---------- add a fund ----------

  void _newFund() {
    final name = TextEditingController();
    final value = TextEditingController();
    showAppSheet<void>(
      context: context,
      builder: (sheet) => SheetFrame(
        title: const Text('Add a mutual fund'),
        content: Column(children: [
          const SizedBox(height: 8),
          SheetField(
            label: 'Fund name',
            controller: name,
            autofocus: true,
            hint: 'e.g. Parag Parikh Flexi Cap',
            capitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),
          SheetField(
            label: 'What is it worth today? (optional)',
            controller: value,
            hint: '0',
            prefix: '₹ ',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(sheet), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.violet100),
            onPressed: () async {
              if (name.text.trim().isEmpty) return;
              Navigator.pop(sheet);
              try {
                await addFund(name.text.trim(), currentValue: double.tryParse(value.text.trim()));
                ref.invalidate(fundsProvider);
                if (mounted) _say('Fund added');
              } catch (e) {
                if (mounted) _say(_err(e));
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  // ---------- put statement payments into a fund ----------

  void _assignSheet(List<Unassigned> un, FundsData d) {
    final picked = <String>{...un.map((x) => x.id)}; // everything ticked to begin with
    String? fundId = d.items.isNotEmpty ? d.items.first.id : null;
    final newName = TextEditingController();
    String dt(DateTime x) => '${shortDate(x)} ${x.year}';
    showAppSheet<void>(
      context: context,
      builder: (sheet) => StatefulBuilder(
        builder: (_, setS) {
          final sum = un.where((x) => picked.contains(x.id)).fold(0.0, (a, x) => a + x.amount);
          return SheetFrame(
            title: const Text('Payments from your statements'),
            content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('These look like mutual fund payments. Tick the ones for the fund below.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              const SizedBox(height: 8),
              for (final x in un)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: AppColors.violet100,
                  value: picked.contains(x.id),
                  onChanged: (v) => setS(() => v == true ? picked.add(x.id) : picked.remove(x.id)),
                  title: Text('${x.merchant}  ·  ${inr(x.amount)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(dt(x.date)),
                ),
              const SizedBox(height: 8),
              const Text('Put them in', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final f in d.items)
                  ChoiceChip(
                    label: Text(f.name),
                    selected: fundId == f.id && newName.text.isEmpty,
                    onSelected: (_) => setS(() {
                      fundId = f.id;
                      newName.clear();
                    }),
                  ),
              ]),
              const SizedBox(height: 8),
              SheetField(
                label: d.items.isEmpty ? 'Fund name' : 'Or a new fund',
                controller: newName,
                hint: 'e.g. Nifty 50 Index',
                onChanged: (_) => setS(() {}),
                capitalization: TextCapitalization.words,
              ),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(sheet), child: const Text('Cancel')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.violet100),
                onPressed: picked.isEmpty || (newName.text.trim().isEmpty && fundId == null)
                    ? null
                    : () async {
                        Navigator.pop(sheet);
                        try {
                          final target = newName.text.trim().isNotEmpty ? await addFund(newName.text.trim()) : fundId!;
                          final n = await assignToFund(target, picked.toList());
                          ref.invalidate(fundsProvider);
                          ref.invalidate(unassignedProvider);
                          if (mounted) _say('$n payment${n == 1 ? '' : 's'} added (${inr(sum)})');
                        } catch (e) {
                          if (mounted) _say(_err(e));
                        }
                      },
                child: Text('Add ${picked.length}'),
              ),
            ],
          );
        },
      ),
    );
  }
}
