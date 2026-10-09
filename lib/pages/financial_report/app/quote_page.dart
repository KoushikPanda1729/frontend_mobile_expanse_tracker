import 'package:expensetracker/commons/components/button/app/solid_button_widget.dart';
import 'package:expensetracker/commons/constants/app_colors.dart';
import 'package:expensetracker/commons/text/app/views/custom_text_library.dart';
import 'package:expensetracker/data/ledger.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class QuotePage extends StatelessWidget {
  const QuotePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.violet100, 
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Title1(
                      text: "“Financial freedom is\nfreedom from fear.”",
                      color: AppColors.light100,
                    ),
                    const SizedBox(height: 14),
                    Title2(
                      text: "- Robert Kiyosaki",
                      color: AppColors.light100,
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 30),
              child: SolidButtonWidget(
                  label: "See the full detail",
                  onPressed: () => Navigator.of(context).pop(),
                  backgroundColor: AppColors.light100,
                  labelColor: AppColors.violet100),
            ),
          ],
        ),
      ),
    );
  }
}

/// Closing slide: the month in four numbers, then straight to the full analysis.
class SummaryPage extends StatelessWidget {
  final String period;
  final double income, expense;
  const SummaryPage(
      {super.key,
      required this.period,
      required this.income,
      required this.expense});

  @override
  Widget build(BuildContext context) {
    final net = income - expense;
    final rate = income > 0 ? (net / income * 100).round() : 0;

    Widget line(String label, String value, Color color) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(color: Colors.grey[700])),
              Text(value,
                  style: TextStyle(
                      color: color, fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
        );

    return Scaffold(
      backgroundColor: AppColors.violet100,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 70),
              Text(period,
                  style: const TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 6),
              const Text('Your month in short',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 28),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(net >= 0 ? 'You saved' : 'You overspent',
                        style: TextStyle(color: Colors.grey[700])),
                    const SizedBox(height: 4),
                    Text(inr(net.abs()),
                        style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: net >= 0
                                ? AppColors.green100
                                : AppColors.red100)),
                    const Divider(height: 28),
                    line('Income', inr(income), AppColors.green100),
                    line('Spent', inr(expense), AppColors.red100),
                    line('Savings rate', '$rate%', AppColors.violet100),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                '"Financial freedom is freedom from fear."\n- Robert Kiyosaki',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white70,
                    fontStyle: FontStyle.italic,
                    height: 1.5),
              ),
              const Spacer(),
              SolidButtonWidget(
                label: 'See full analysis',
                onPressed: () {
                  final router = GoRouter.of(context);
                  Navigator.of(context).pop();
                  router.push('/analysis');
                },
                backgroundColor: AppColors.light100,
                labelColor: AppColors.violet100,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
