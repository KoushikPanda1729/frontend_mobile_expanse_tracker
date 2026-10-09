import 'package:expensetracker/commons/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class TransactionCard extends StatelessWidget {
  final String icon;
  final String title;
  final String? description;
  final String? date;
  final String? time;
  final String? amount;
  final Color iconColor;
  final bool isIncome;
  final VoidCallback onTap;
  const TransactionCard(
      {super.key,
      required this.icon,
      required this.iconColor,
      required this.title,
      this.description,
      this.date,
      this.time,
      this.amount,
      required this.isIncome,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: SvgPicture.asset(icon,
                  colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                fontSize: 16,
                                height: 1.4,
                                fontWeight: FontWeight.w500)),
                        Text(description ?? '',
                            style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                                height: 1.5,
                                overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        amount ?? '',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            height: 1.4,
                            color: isIncome
                                ? AppColors.green100
                                : AppColors.red100),
                      ),
                      Text(time ?? "",
                          style: const TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey)),
                    ],
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
