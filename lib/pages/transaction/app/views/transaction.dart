import 'package:expensetracker/commons/components/custom_bottom_sheet/app/open_custom_bottom_sheet.dart';
import 'package:expensetracker/commons/components/filter_bottomsheet/app/filter_bottomsheet.dart';
import 'package:expensetracker/commons/components/notification_bar/notification_bar.dart';
import 'package:expensetracker/commons/components/month_pill/month_pill.dart';
import 'package:expensetracker/commons/components/transaction_card/app/transaction_card.dart';
import 'package:expensetracker/commons/constants/app_colors.dart';
import 'package:expensetracker/commons/constants/app_icons.dart';
import 'package:expensetracker/commons/text/app/views/custom_text_library.dart';
import 'package:expensetracker/pages/financial_report/app/financial_report.dart';
import 'package:expensetracker/data/ledger.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TransactionScreen extends ConsumerWidget {
  const TransactionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(ledgerProvider).valueOrNull;
    if (ledger == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final keys = ledger.monthKeys;
    final key = ref.watch(monthProvider) ?? keys.last;
    final filter = ref.watch(filterProvider);
    final active = filter.type != null || filter.sort != null || filter.categories.isNotEmpty;
    final list = filter.apply(ledger.inMonth(key));
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NotificationBar(
                trailingIcon: AppIcons.sortIcon,
                isFiltered: active,
                child: Row(
                  children: [
                    const MonthPill(),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => context.push('/import'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: AppColors.violet100.withOpacity(0.4)),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.upload_file,
                                size: 18, color: AppColors.violet100),
                            SizedBox(width: 6),
                            Text('Import',
                                style: TextStyle(
                                    color: AppColors.violet100,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                onTap: () {
                  openCustomBottomSheet(
                    context: context,
                    child: const FilterBottomSheet(),
                  );
                },
              ),
              const SizedBox(height: 12),
              TextField(
                onChanged: (q) => ref.read(filterProvider.notifier).state =
                    ref.read(filterProvider).withQuery(q),
                decoration: InputDecoration(
                  hintText: 'Search merchant or category',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.grey.withOpacity(0.08),
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const FinancialReport()),
                  );
                },
                child: NotificationBar(
                  isTrailingIcon: true,
                  trailingIcon: AppIcons.arrowRight2Icon,
                  backgroundColor: AppColors.green100.withOpacity(0.1),
                  isFiltered: false,
                  title: "See your financial report",
                  onTap: () {},
                ),
              ),
              const SizedBox(height: 24),
              _buildTransactionsList(list),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionsList(List<Txn> txns) {
    final byDay = <DateTime, List<Txn>>{};
    for (final t in txns) {
      byDay.putIfAbsent(t.date, () => []).add(t);
    }
    if (txns.isEmpty) {
      return const Expanded(child: Center(child: Text('No transactions')));
    }
    return Expanded(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          for (final e in byDay.entries)
            _buildDateSection(
                '${_weekdays[e.key.weekday - 1]}, ${shortDate(e.key)}',
                e.value.length > 1
                    ? e.value.fold<double>(0.0, (a, t) => a + t.signed)
                    : null,
                [
              for (final t in e.value) ...[
                TransactionCard(
                  icon: t.category.icon,
                  iconColor: t.category.color,
                  isIncome: t.isIncome,
                  title: t.merchant,
                  description: '${t.category.name} · ${t.mode}',
                  amount: '${t.isIncome ? '+' : '-'} ${inr(t.amount)}',
                  onTap: () {},
                ),
                const SizedBox(height: 8),
              ],
            ]),
        ],
      ),
    );
  }

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  Widget _buildDateSection(
      String date, double? net, List<Widget> transactions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Title3(text: date),
              if (net != null)
                Text(
                  '${net >= 0 ? '+' : '-'} ${inr(net.abs())}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: net >= 0 ? AppColors.green100 : AppColors.red100,
                  ),
                ),
            ],
          ),
        ),
        ...transactions,
      ],
    );
  }
}
