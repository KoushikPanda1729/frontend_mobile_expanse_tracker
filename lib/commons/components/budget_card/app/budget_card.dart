import 'package:expensetracker/data/ledger.dart';
import 'package:expensetracker/commons/constants/app_colors.dart';
import 'package:expensetracker/commons/constants/app_icons.dart';
import 'package:expensetracker/commons/text/app/views/custom_text_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class BudgetCard extends StatelessWidget {
  final String title;
  final Color color;
  final double spent;
  final double total;
  const BudgetCard({
    super.key,
    required this.title,
    required this.color,
    required this.spent,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (spent / total).clamp(0.0, 1.0);
    final isOverBudget = total < spent;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.light100,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (isOverBudget)
                SvgPicture.asset(
                  AppIcons.warningIcon,
                  colorFilter: const ColorFilter.mode(
                    AppColors.red100,
                    BlendMode.srcIn,
                  ),
                )
            ],
          ),
          const SizedBox(height: 8),
          Title2(
            text: '${isOverBudget ? 'Over by' : 'Remaining'} ${inr((total - spent).abs())}',
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(
                isOverBudget ? AppColors.red100 : color,
              ),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${inr(spent)} of ${inr(total)}',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 16,
            ),
          ),
          if (isOverBudget) ...[
            const SizedBox(height: 10),
            const Text(
              "You've exceeded the limit!",
              style: TextStyle(
                color: Colors.red,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
