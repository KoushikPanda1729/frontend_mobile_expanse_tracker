import 'package:expensetracker/commons/components/sheets/app_sheets.dart';
import 'package:expensetracker/commons/constants/app_colors.dart';
import 'package:expensetracker/data/api.dart';
import 'package:expensetracker/data/ledger.dart';
import 'package:expensetracker/data/statements.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Every imported statement: download the unlocked PDF, or delete it with its transactions.
class StatementsPage extends ConsumerStatefulWidget {
  const StatementsPage({super.key});

  @override
  ConsumerState<StatementsPage> createState() => _StatementsPageState();
}

class _StatementsPageState extends ConsumerState<StatementsPage> {
  String? _busyId;

  String _d(DateTime? d) => d == null ? '-' : '${shortDate(d)} ${d.year}';

  String _size(int b) => b < 1024 * 1024
      ? '${(b / 1024).round()} KB'
      : '${(b / 1024 / 1024).toStringAsFixed(1)} MB';

  void _say(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  String _err(Object e) => e is ApiException
      ? e.message
      : e is MissingPluginException
          ? 'The app needs a full restart after adding a plugin: stop it and run it again.'
          : 'Something went wrong: $e';

  Future<void> _view(StatementInfo s) async {
    setState(() => _busyId = s.id);
    try {
      await viewStatement(s);
    } catch (e) {
      _say(_err(e));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _reread(StatementInfo s) async {
    setState(() => _busyId = s.id);
    try {
      final n = await rereadStatement(s.id);
      await ref.read(ledgerProvider.notifier).refresh();
      _say(n == 0 ? 'Nothing was missing. All details are already saved.' : 'Filled in details for $n transactions.');
    } catch (e) {
      _say(_err(e));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _download(StatementInfo s) async {
    setState(() => _busyId = s.id);
    try {
      await shareStatement(s);
    } catch (e) {
      _say(_err(e));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _delete(StatementInfo s) async {
    final ok = await showAppSheet<bool>(
      context: context,
      builder: (d) => SheetFrame(
        title: const Text('Delete statement?'),
        content: Text(
            '${s.fileName} and the ${s.transactionCount} transactions imported from it will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(d, true),
              child: const Text('Delete', style: TextStyle(color: AppColors.red100))),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busyId = s.id);
    try {
      await deleteStatement(s.id);
      await ref.read(ledgerProvider.notifier).refresh();
      ref.invalidate(statementsProvider);
      _say('Statement deleted');
    } catch (e) {
      _say(_err(e));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(statementsProvider);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.dark100,
        centerTitle: true,
        title: const Text('My statements', style: TextStyle(fontWeight: FontWeight.w700)),
        leading: BackButton(onPressed: () => context.canPop() ? context.pop() : context.go('/')),
      ),
      body: list.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Could not load statements\n${_err(e)}', textAlign: TextAlign.center),
              TextButton(
                  onPressed: () => ref.invalidate(statementsProvider),
                  child: const Text('Retry')),
            ],
          ),
        ),
        data: (items) => items.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('No statements yet', style: TextStyle(color: Colors.grey[600])),
                    TextButton(
                        onPressed: () => context.push('/import'),
                        child: const Text('Import a statement')),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: () async => ref.refresh(statementsProvider.future),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _card(items[i]),
                ),
              ),
      ),
    );
  }

  Widget _stat(String label, String value) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      );

  Widget _card(StatementInfo s) {
    final busy = _busyId == s.id;
    final net = (s.closingBalance != null && s.openingBalance != null)
        ? s.closingBalance! - s.openingBalance!
        : null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.violet20.withOpacity(0.45),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: AppColors.violet100.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.picture_as_pdf_outlined,
                    color: AppColors.violet100),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('${s.bank} · ${_d(s.periodStart)} - ${_d(s.periodEnd)}',
                        style: TextStyle(color: Colors.grey[700], fontSize: 12.5)),
                  ],
                ),
              ),
              if (s.wasLocked)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: AppColors.violet100.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_open, size: 13, color: AppColors.violet100),
                      SizedBox(width: 4),
                      Text('Unlocked',
                          style: TextStyle(
                              color: AppColors.violet100,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _stat('Transactions', '${s.transactionCount}'),
              const SizedBox(width: 8),
              _stat('Size', _size(s.sizeBytes)),
              const SizedBox(width: 8),
              _stat('Added', _d(s.createdAt)),
            ],
          ),
          if (s.openingBalance != null && s.closingBalance != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.account_balance_wallet_outlined,
                    size: 16, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                      'Balance ${inr(s.openingBalance!)} to ${inr(s.closingBalance!)}',
                      style: TextStyle(color: Colors.grey[700], fontSize: 12.5)),
                ),
                if (net != null)
                  Text('${net >= 0 ? '+' : '-'} ${inr(net.abs())}',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: net >= 0 ? AppColors.green100 : AppColors.red100)),
              ],
            ),
          ],
          const SizedBox(height: 14),
          if (busy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(minHeight: 3),
            )
          else
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.violet100,
                      minimumSize: const Size.fromHeight(44),
                    ),
                    onPressed: () => _view(s),
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('View'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.violet100,
                      side: const BorderSide(color: AppColors.violet100),
                      minimumSize: const Size.fromHeight(44),
                    ),
                    onPressed: () => _download(s),
                    icon: const Icon(Icons.ios_share, size: 18),
                    label: const Text('Share'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  style: IconButton.styleFrom(
                    side: const BorderSide(color: AppColors.red100),
                    minimumSize: const Size(44, 44),
                  ),
                  tooltip: 'Delete',
                  onPressed: () => _delete(s),
                  icon: const Icon(Icons.delete_outline, color: AppColors.red100),
                ),
              ],
            ),
          if (!busy)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 4)),
                onPressed: () => _reread(s),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh details from this PDF', style: TextStyle(fontSize: 12.5)),
              ),
            ),
        ],
      ),
    );
  }
}
