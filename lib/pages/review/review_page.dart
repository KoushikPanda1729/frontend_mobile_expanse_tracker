import 'package:expensetracker/commons/constants/app_colors.dart';
import 'package:expensetracker/data/ledger.dart';
import 'package:expensetracker/data/review.dart';
import 'package:expensetracker/pages/review/review_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// "Check your money": payments the app cannot explain, so the user can look them up and label them.
class ReviewPage extends ConsumerWidget {
  const ReviewPage({super.key});

  String _d(DateTime d) => '${shortDate(d)} ${d.year}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final review = ref.watch(reviewProvider);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.dark100,
        centerTitle: true,
        title: const Text('Check your money', style: TextStyle(fontWeight: FontWeight.w700)),
        leading: BackButton(onPressed: () => context.canPop() ? context.pop() : context.go('/')),
      ),
      body: review.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Could not load\n$e', textAlign: TextAlign.center),
              TextButton(
                  onPressed: () => ref.invalidate(reviewProvider), child: const Text('Retry')),
            ],
          ),
        ),
        data: (r) => r.count == 0 ? _allClear() : _list(context, ref, r),
      ),
    );
  }

  Widget _allClear() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.verified_outlined, size: 56, color: AppColors.green100),
              const SizedBox(height: 14),
              const Text('Nothing to check',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('Every payment is either explained or labelled by you.',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
            ],
          ),
        ),
      );

  Widget _list(BuildContext context, WidgetRef ref, Review r) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        _summary(r),
        const SizedBox(height: 12),
        Text(
          'The bank only prints a short name and a UPI id. Tap an item to see the phone number and reference number: search them in your UPI app to find who it was, then label it once.',
          style: TextStyle(color: Colors.grey[700], height: 1.4, fontSize: 13),
        ),
        if (r.flagged.isNotEmpty) ...[
          _title('Worth a look', '${r.flagged.length}'),
          for (final f in r.flagged) _flaggedCard(context, ref, f),
        ],
        if (r.payees.isNotEmpty) ...[
          _title('People and shops you have not labelled', '${r.payees.length}'),
          for (final p in r.payees) _payeeCard(context, ref, p),
        ],
      ],
    );
  }

  Widget _title(String t, String n) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 10),
        child: Row(
          children: [
            Expanded(
                child: Text(t,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                  color: AppColors.violet20, borderRadius: BorderRadius.circular(10)),
              child: Text(n,
                  style: const TextStyle(
                      color: AppColors.violet100, fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ],
        ),
      );

  Widget _summary(Review r) {
    Widget pill(String label, String v) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.16), borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(v,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.violet80, AppColors.violet100]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${r.count} to check',
              style: const TextStyle(
                  color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Row(
            children: [
              pill('Sent to people', inr(r.unknownSent)),
              const SizedBox(width: 10),
              pill('Flagged payments', inr(r.flaggedAmount)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _reasonChip(String t) {
    final danger = t == 'Bank charge' || t.startsWith('Paid twice');
    final c = danger ? AppColors.red100 : AppColors.violet100;
    return Container(
      margin: const EdgeInsets.only(right: 6, top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(t, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _card({required Widget child, required VoidCallback onTap}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: Colors.grey.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(padding: const EdgeInsets.all(14), child: child),
          ),
        ),
      );

  Widget _flaggedCard(BuildContext context, WidgetRef ref, FlaggedTxn f) {
    return _card(
      onTap: () => _flaggedSheet(context, ref, f),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(f.merchant,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('${_d(f.date)} · ${f.category}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                Wrap(children: [for (final r in f.reasons) _reasonChip(r)]),
              ],
            ),
          ),
          Text(inr(f.amount),
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: AppColors.red100)),
        ],
      ),
    );
  }

  Widget _payeeCard(BuildContext context, WidgetRef ref, UnknownPayee p) {
    return _card(
      onTap: () => _payeeSheet(context, ref, p),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.violet20,
            child: Text(p.merchant.isEmpty ? '?' : p.merchant[0].toUpperCase(),
                style: const TextStyle(
                    color: AppColors.violet100, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.merchant,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                    'Sent ${inr(p.sent)} in ${p.sentCount} payment${p.sentCount == 1 ? '' : 's'}'
                    '${p.received > 0 ? ' · got back ${inr(p.received)}' : ''}',
                    style: TextStyle(color: Colors.grey[700], fontSize: 12.5)),
                if (p.phone != null || p.upiId != null)
                  Text(p.phone != null ? 'Phone ${p.phone}' : 'UPI ${p.upiId}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.violet100),
        ],
      ),
    );
  }

  void _payeeSheet(BuildContext context, WidgetRef ref, UnknownPayee p) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.merchant,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              copyRow(sheet, 'You sent', '${inr(p.sent)} (${p.sentCount} payments)', copy: false),
              if (p.received > 0)
                copyRow(sheet, 'They sent', '${inr(p.received)} (${p.receivedCount} payments)',
                    copy: false),
              copyRow(sheet, 'Net', '${p.net >= 0 ? '+' : '-'} ${inr(p.net.abs())}', copy: false),
              copyRow(sheet, 'Dates', '${_d(p.first)} to ${_d(p.last)}', copy: false),
              if (p.phone != null) copyRow(sheet, 'Phone', p.phone!),
              if (p.upiId != null && p.phone == null) copyRow(sheet, 'UPI id', p.upiId!),
              if (p.bank != null) copyRow(sheet, 'Bank', p.bank!, copy: false),
              const SizedBox(height: 10),
              Text(
                  p.phone != null
                      ? 'Search this number in your contacts or UPI app to see who it is.'
                      : 'Search this UPI id in your UPI app to see the name you paid.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.35)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.violet100,
                      minimumSize: const Size.fromHeight(48)),
                  onPressed: () {
                    Navigator.pop(sheet);
                    showLabelPayeeSheet(context, ref, p.merchant);
                  },
                  child: const Text('I know this payee'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _flaggedSheet(BuildContext context, WidgetRef ref, FlaggedTxn f) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(f.merchant,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                Text('- ${inr(f.amount)}',
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.red100)),
                Wrap(children: [for (final r in f.reasons) _reasonChip(r)]),
                const SizedBox(height: 10),
                copyRow(sheet, 'Date', _d(f.date), copy: false),
                copyRow(sheet, 'Category', f.category, copy: false),
                if (f.phone != null) copyRow(sheet, 'Phone', f.phone!),
                if (f.upiId != null && f.phone == null) copyRow(sheet, 'UPI id', f.upiId!),
                if (f.bank != null) copyRow(sheet, 'Bank', f.bank!, copy: false),
                if (f.ref != null) copyRow(sheet, 'Reference', f.ref!),
                if (f.description != null) ...[
                  const SizedBox(height: 8),
                  Text('Bank description',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(f.description!, style: const TextStyle(fontSize: 13, height: 1.35)),
                ],
                const SizedBox(height: 10),
                Text(
                    'Not yours? Copy the reference number and ask your bank, or search it in your UPI app.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.35)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.violet100,
                        minimumSize: const Size.fromHeight(48)),
                    onPressed: () {
                      Navigator.pop(sheet);
                      showLabelPayeeSheet(context, ref, f.merchant);
                    },
                    child: const Text('I know this payee'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
