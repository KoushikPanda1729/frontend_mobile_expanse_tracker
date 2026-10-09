import 'package:expensetracker/commons/constants/app_colors.dart';
import 'package:expensetracker/commons/constants/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class StatButton extends StatefulWidget {
  const StatButton({super.key});

  @override
  State<StatButton> createState() => _StatButtonState();
}

class _StatButtonState extends State<StatButton> {
  bool isSelected = true;
  void toggleSelection(bool selectedBotton) {
    if (isSelected != selectedBotton) {
      setState(() {
        isSelected = selectedBotton;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => toggleSelection(true),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.violet100 : Colors.transparent,
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10.0),
                  bottomLeft: Radius.circular(10)),
            ),
            child: SvgPicture.asset(
              AppIcons.lineChart2Icon,
              colorFilter: ColorFilter.mode(isSelected ? AppColors.light100 : AppColors.violet100, BlendMode.srcIn),
            ),
          ),
        ),
        GestureDetector(
          onTap: () => toggleSelection(false),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected ? Colors.transparent : AppColors.violet100,
              borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(10.0),
                  bottomRight: Radius.circular(10)),
            ),
            child: SvgPicture.asset(
              AppIcons.pieChartIcon,
              colorFilter: ColorFilter.mode(
                  isSelected ? AppColors.violet100 : AppColors.light100, BlendMode.srcIn),
            ),
          ),
        )
      ],
    );
  }
}
