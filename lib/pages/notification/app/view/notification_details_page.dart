import 'package:expensetracker/commons/constants/app_colors.dart';
import 'package:expensetracker/commons/components/notification_bar/notification_bar.dart';
import 'package:expensetracker/commons/constants/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class NotificationDetailPage extends StatelessWidget {
  final Map<String, String> notification;

  const NotificationDetailPage({super.key, required this.notification});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Notification Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: NotificationBar(
                isPrifileVisible: false,
                isTrailingIcon: false,
                leadingIcon: AppIcons.arrowLeftIcon,
                title: "Notification Details",
                isFiltered: false,
                onTap: () => context.pop(),
              ),
            ),

            // Notification Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification["title"]!,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.dark100,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      notification["message"]!,
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.dark50,
                        height: 1.5,
                      ),
                    ),
                    const Spacer(),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        notification["time"]!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.dark50,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
