import 'package:expensetracker/commons/constants/app_colors.dart';
import 'package:expensetracker/commons/constants/app_icons.dart';
import 'package:expensetracker/commons/text/app/views/custom_text_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class MenuItem extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final bool hasNotification;
  final bool showToggle;
  final bool isLogout;
  final String amount;
  final VoidCallback? onTap;

  const MenuItem({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    this.hasNotification = false,
    this.showToggle = false,
    this.isLogout = false,
    this.amount = "",
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.all(16),
      leading: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: SvgPicture.asset(
          icon,
          colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isLogout ? Colors.red : Colors.black,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 12,
        ),
      ),
      trailing: amount != ""
          ? Title3(text: "₹ $amount")
          : isLogout == true
              ? const SizedBox.shrink()
              : SvgPicture.asset(
                  AppIcons.arrowRight2Icon,
                  colorFilter: ColorFilter.mode(
                    AppColors.dark100.withOpacity(0.2),
                    BlendMode.srcIn,
                  ),
                ),
    );
  }
}
