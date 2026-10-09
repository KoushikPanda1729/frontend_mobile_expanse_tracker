import 'package:expensetracker/commons/constants/app_colors.dart';
import 'package:expensetracker/data/ledger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Compact month selector: tap to pick from months that have data.
class MonthPill extends ConsumerWidget {
  const MonthPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keys = ref.watch(ledgerProvider).valueOrNull?.monthKeys ?? const [];
    if (keys.isEmpty) return const SizedBox.shrink();
    final key = ref.watch(monthProvider) ?? keys.last;

    return GestureDetector(
      onTap: () => showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (sheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select month',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                for (final k in keys.reversed)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${monthLabel(k)} ${k ~/ 100}',
                      style: TextStyle(
                        fontWeight:
                            k == key ? FontWeight.w700 : FontWeight.w500,
                        color: k == key ? AppColors.violet100 : null,
                      ),
                    ),
                    trailing: k == key
                        ? const Icon(Icons.check, color: AppColors.violet100)
                        : null,
                    onTap: () {
                      ref.read(monthProvider.notifier).state = k;
                      Navigator.pop(sheet);
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 9, 10, 9),
        decoration: BoxDecoration(
          color: AppColors.violet20,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              monthLabel(key),
              style: const TextStyle(
                color: AppColors.violet100,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded,
                size: 20, color: AppColors.violet100),
          ],
        ),
      ),
    );
  }
}
