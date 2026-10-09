import 'package:expensetracker/commons/components/custom_switch/app/custom_switch.dart';
import 'package:flutter/material.dart';

class RepeateTransactionWidget extends StatelessWidget {
  const RepeateTransactionWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Repeat',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Repeat transaction',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        CustomSwitch(
          value: true,
          onChanged: (value) => value,
        ),
      ],
    );
  }
}
