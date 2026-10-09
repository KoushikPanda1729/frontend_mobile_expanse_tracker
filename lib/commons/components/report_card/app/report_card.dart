import 'package:expensetracker/commons/constants/app_colors.dart';
import 'package:expensetracker/commons/text/app/views/custom_text_library.dart';
import 'package:expensetracker/pages/financial_report/app/budget_page.dart';
import 'package:flutter/material.dart';

class ReportCard extends StatelessWidget {
  final String title;
  final String icon;
  final Color iconColor;
  final String category;
  final String totalCost;
  const ReportCard({
    super.key,
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.category,
    required this.totalCost,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.light100,
        borderRadius: BorderRadius.circular(8),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Title2(
              text: title,
              color: AppColors.dark100,
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                BudgetbuttonCard(
                  icon: icon,
                  iconColor: iconColor,
                  category: category,
                ),
              ],
            ),
            const SizedBox(
              height: 10,
            ),
            Title2(text: totalCost)
          ],
        ),
      ),
    );
  }
}
