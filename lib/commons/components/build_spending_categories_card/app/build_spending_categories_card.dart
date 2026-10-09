import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class BuildSpendingCategoriesCard extends StatelessWidget {
  final Color cardColor;
  final String icon;
  final Color iconColor;
  final String cardTitle;
  final String incomeExpenses;
  final void Function() onTap;

  const BuildSpendingCategoriesCard({
    super.key,
    required this.cardColor,
    required this.icon,
    required this.iconColor,
    required this.cardTitle,
    required this.incomeExpenses,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SvgPicture.asset(
                icon,
                colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  children: [
                    Text(cardTitle,
                        style: const TextStyle(color: Colors.white)),
                    const SizedBox(
                      height: 4,
                    ),
                    Text(
                      incomeExpenses,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
