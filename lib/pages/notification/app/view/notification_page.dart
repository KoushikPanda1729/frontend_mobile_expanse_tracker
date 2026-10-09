import 'package:expensetracker/commons/components/custom_bottom_sheet/app/open_custom_bottom_sheet.dart';
import 'package:expensetracker/commons/components/notification_bar/notification_bar.dart';
import 'package:expensetracker/commons/constants/app_colors.dart';
import 'package:expensetracker/commons/constants/app_icons.dart';
import 'package:expensetracker/data/ledger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class NotificationPage extends ConsumerWidget {
  const NotificationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Alerts built from the ledger: exceeded budgets and big incoming money.
    final ledger = ref.watch(ledgerProvider).valueOrNull;
    final budgets = ref.watch(budgetsProvider);
    final notifications = <Map<String, String>>[];
    if (ledger != null) {
      final txns = ledger.inMonth(ledger.monthKeys.last);
      final spent = {for (final e in Ledger.byCategory(txns)) e.key.name: e.value};
      for (final b in budgets.entries) {
        final s = spent[b.key] ?? 0;
        if (s > b.value) {
          notifications.add({
            "title": "${b.key} budget has exceeded the limit",
            "description": "You spent ${inr(s)} of your ${inr(b.value)} limit.",
            "time": "This month",
          });
        }
      }
      for (final t in txns.reversed.where((t) => t.isIncome && t.amount >= 1000).take(5)) {
        notifications.add({
          "title": "${inr(t.amount)} received",
          "description": "${t.category.name} from ${t.merchant}.",
          "time": shortDate(t.date),
        });
      }
    }
    if (notifications.isEmpty) {
      notifications.add({
        "title": "All clear",
        "description": "No budget alerts this month.",
        "time": "Now",
      });
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Notification Bar (Reused Component)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: NotificationBar(
                isPrifileVisible: false,
                trailingIcon: AppIcons.moreHorizontalIcon,
                leadingIcon: AppIcons.arrowLeftIcon,
                title: "Notifications",
                isFiltered: false,
                onTap: () {
                  context.pop();
                },
                onTapTrailing: () {
                  openCustomBottomSheet(
                      context: context,
                      child: const NotificationActionsSheet());
                },
              ),
            ),

            // Expanded List of Notifications
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 8),
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final notification = notifications[index];

                  return NotificationItem(
                    title: notification["title"]!,
                    description: notification["description"]!,
                    time: notification["time"]!,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Reusable NotificationItem Widget
class NotificationItem extends StatelessWidget {
  final String title;
  final String description;
  final String time;

  const NotificationItem({
    super.key,
    required this.title,
    required this.description,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            spreadRadius: 2,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Notification Text
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.9,
                  fontWeight: FontWeight.w500,
                  color: AppColors.dark100,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.dark100.withOpacity(0.5),
                ),
              ),
            ],
          ),

          // Notification Time
          Text(
            time,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

class NotificationActionsSheet extends StatelessWidget {
  const NotificationActionsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () {
              // Add your logic for "Mark all read"
              Navigator.pop(context);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              alignment: Alignment.center,
              child: const Text(
                "Mark all read",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          const Divider(),
          GestureDetector(
            onTap: () {
              // Add your logic for "Remove all"
              Navigator.pop(context);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              alignment: Alignment.center,
              child: const Text(
                "Remove all",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
