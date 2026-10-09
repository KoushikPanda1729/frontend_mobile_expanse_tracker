import 'package:expensetracker/commons/components/report_card/app/report_card.dart';
import 'package:expensetracker/commons/constants/app_colors.dart';
import 'package:expensetracker/commons/text/app/views/custom_text_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SpendingEarningPage extends StatelessWidget {
  final String title;
  final String totalSpendAndEarned;
  final Color backgroundColor;
  final String cardTitle;
  final List<String> icons;
  final List<String> categories;
  final String maxEarnAndSpend;
  final bool isBudget;
  final String period; // e.g. "March 2026"
  final String subtitle; // e.g. "12% less than February"
  final List<ReportItem> items; // top categories shown in the card

  const SpendingEarningPage({
    super.key,
    required this.backgroundColor,
    required this.title,
    required this.totalSpendAndEarned,
    required this.cardTitle,
    required this.categories,
    required this.icons,
    required this.maxEarnAndSpend,
    this.isBudget = false,
    this.period = 'This Month',
    this.subtitle = '',
    this.items = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            const SizedBox(height: 24),
            Title2(text: period, color: AppColors.light100),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  // plain Text so long titles wrap instead of overflowing
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  if (!isBudget) ...[
                    const SizedBox(height: 20),
                    TitleX(
                      text: totalSpendAndEarned,
                      color: AppColors.light100,
                    ),
                  ],
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(subtitle,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ],
              ),
            ),
            if (items.isNotEmpty)
              _TopCard(title: cardTitle, items: items, color: backgroundColor)
            else if (!isBudget)
              ReportCard(
                title: cardTitle,
                icon: icons.isNotEmpty ? icons.first : "",
                iconColor: backgroundColor,
                category: categories.isNotEmpty ? categories.first : "",
                totalCost: maxEarnAndSpend,
              )
            else
              const SizedBox.shrink(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// One row in the story card: category icon, name, amount and its share of the total.
class ReportItem {
  final String icon, name, amount;
  final double share; // 0..1
  final String? trailing; // replaces "amount  %" when set
  final Color? barColor;
  const ReportItem(this.icon, this.name, this.amount, this.share,
      {this.trailing, this.barColor});
}

class _TopCard extends StatelessWidget {
  final String title;
  final List<ReportItem> items;
  final Color color;
  const _TopCard(
      {required this.title, required this.items, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          for (final i in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: SvgPicture.asset(
                      i.icon,
                      width: 20,
                      height: 20,
                      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(i.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            Text(
                                i.trailing ??
                                    '${i.amount}  ${(i.share * 100).round()}%',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: i.share.clamp(0.0, 1.0),
                            minHeight: 6,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation(i.barColor ?? color),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
