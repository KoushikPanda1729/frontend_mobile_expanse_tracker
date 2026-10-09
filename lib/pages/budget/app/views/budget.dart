import 'package:expensetracker/commons/components/button/app/solid_button_widget.dart';
import 'package:expensetracker/commons/components/month_pill/month_pill.dart';
import 'package:expensetracker/commons/constants/app_colors.dart';
import 'package:expensetracker/data/ledger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(ledgerProvider).valueOrNull;
    if (ledger == null) {
      return const Scaffold(
          backgroundColor: Colors.white,
          body: Center(child: CircularProgressIndicator()));
    }
    final key = ref.watch(monthProvider) ?? ledger.monthKeys.last;
    final budgets = ref.watch(budgetsProvider);
    final spent = {
      for (final e in Ledger.byCategory(ledger.inMonth(key))) e.key.name: e.value
    };

    final totalBudget = budgets.values.fold(0.0, (a, b) => a + b);
    final totalSpent = budgets.keys.fold(0.0, (a, k) => a + (spent[k] ?? 0));
    // most used first, so problems show at the top
    final rows = budgets.entries.toList()
      ..sort((a, b) => ((spent[b.key] ?? 0) / b.value)
          .compareTo((spent[a.key] ?? 0) / a.value));

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Budget',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
            const Spacer(),
            const MonthPill(),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _edit(context, ref),
              child: Container(
                padding: const EdgeInsets.all(9),
                decoration: const BoxDecoration(
                    color: AppColors.violet100, shape: BoxShape.circle),
                child: const Icon(Icons.add, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
            const SizedBox(height: 20),
            if (budgets.isNotEmpty)
              _summary(key, totalSpent, totalBudget)
            else
              Container(
                padding: const EdgeInsets.symmetric(vertical: 36),
                alignment: Alignment.center,
                child: Text("No budgets yet.\nSet a monthly limit per category.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600], height: 1.5)),
              ),
            const SizedBox(height: 24),
            for (final e in rows)
              _row(context, ref, budgets, e.key, spent[e.key] ?? 0, e.value),
          ],
        ),
      ),
    );
  }

  Widget _summary(int key, double spent, double total) {
    final left = total - spent;
    final over = left < 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.violet80, AppColors.violet100],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Spent in ${monthLabel(key)}',
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(inr(spent),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : (spent / total).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('of ${inr(total)} budget',
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
              Text(over ? 'Over by ${inr(-left)}' : '${inr(left)} left',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, WidgetRef ref, Map<String, double> budgets,
      String name, double spent, double limit) {
    final cat = categoryByName(name);
    final over = spent > limit;
    final color = over ? AppColors.red100 : cat.color;
    return Dismissible(
      key: ValueKey(name),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
            color: AppColors.red100, borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => ref.read(budgetsProvider.notifier).state = {
        ...budgets
      }..remove(name),
      child: GestureDetector(
        onTap: () => _edit(context, ref, cat: name, limit: limit),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: cat.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: SvgPicture.asset(
                      cat.icon,
                      width: 18,
                      height: 18,
                      colorFilter: ColorFilter.mode(cat.color, BlendMode.srcIn),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  Text.rich(TextSpan(children: [
                    TextSpan(
                        text: inr(spent),
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: over ? AppColors.red100 : null)),
                    TextSpan(
                        text: ' / ${inr(limit)}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  ])),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (spent / limit).clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  over ? 'Over by ${inr(spent - limit)}' : '${inr(limit - spent)} left',
                  style: TextStyle(
                      color: over ? AppColors.red100 : Colors.grey[600],
                      fontSize: 12,
                      fontWeight: over ? FontWeight.w600 : FontWeight.w400),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Add a budget, or edit one when [cat] and [limit] are given.
  void _edit(BuildContext context, WidgetRef ref, {String? cat, double? limit}) {
    final ctrl = TextEditingController(
        text: limit == null ? '' : limit.toStringAsFixed(0));
    var picked = cat ?? expenseCategories.first.name;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheet) => StatefulBuilder(
        builder: (_, setS) => Padding(
          padding: EdgeInsets.fromLTRB(
              16, 20, 16, 16 + MediaQuery.of(sheet).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(cat == null ? 'New budget' : 'Edit $cat budget',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600)),
              TextField(
                controller: ctrl,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                    prefixText: '₹ ', hintText: '0', border: InputBorder.none),
              ),
              if (cat == null)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in expenseCategories)
                      ChoiceChip(
                        label: Text(c.name),
                        selected: picked == c.name,
                        onSelected: (_) => setS(() => picked = c.name),
                      ),
                  ],
                ),
              const SizedBox(height: 20),
              SolidButtonWidget(
                label: 'Save',
                onPressed: () {
                  final v = double.tryParse(ctrl.text);
                  if (v == null || v <= 0) return;
                  ref.read(budgetsProvider.notifier).state = {
                    ...ref.read(budgetsProvider),
                    picked: v,
                  };
                  Navigator.pop(sheet);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
