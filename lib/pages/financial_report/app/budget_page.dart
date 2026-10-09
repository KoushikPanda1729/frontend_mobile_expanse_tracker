import 'package:expensetracker/commons/constants/app_colors.dart';
import 'package:expensetracker/commons/text/app/views/custom_text_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class BudgetbuttonCard extends StatelessWidget {
  final String icon;
  final Color iconColor;
  final String category;
  const BudgetbuttonCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.category,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          width: 2,
          color: AppColors.dark100.withOpacity(0.1),
        ),
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SvgPicture.asset(
              icon,
              colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
            ),
          ),
          const SizedBox(
            width: 8,
          ),
          Title3(text: category)
        ],
      ),
    );
  }
}
