import 'package:expensetracker/commons/components/button/app/solid_button_widget.dart';
import 'package:expensetracker/commons/components/profile_avatar/profile_avatar.dart';
import 'package:expensetracker/commons/components/stat_button/app/stat_button.dart';
import 'package:expensetracker/commons/constants/app_icons.dart';
import 'package:expensetracker/commons/text/app/views/custom_text_library.dart';
import 'package:flutter/material.dart';
import 'package:expensetracker/commons/constants/app_colors.dart';
import 'package:expensetracker/commons/constants/app_images.dart';
import 'package:flutter_svg/flutter_svg.dart';

class NotificationBar extends StatelessWidget {
  final String? leadingIcon;
  final String? title;
  final String? trailingIcon;
  final Widget child;
  final bool? isPrifileVisible;
  final bool? isTrailingIcon;
  final bool? isBottonRequired;
  final bool? isFiltered;
  final bool? isStatButton;
  final Color? backgroundColor;
  final Color? labelColor;
  final void Function() onTap;
  final void Function()? onTapTrailing;

  const NotificationBar({
    super.key,
    this.leadingIcon,
    this.title,
    this.trailingIcon,
    this.child = const SizedBox(),
    required this.onTap,
    this.onTapTrailing,
    this.isPrifileVisible = false,
    this.isTrailingIcon = true,
    this.isBottonRequired = false,
    this.isFiltered = true,
    this.backgroundColor,
    this.labelColor,
    this.isStatButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: backgroundColor != null
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: backgroundColor,
            )
          : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              leadingIcon != null
                  ? GestureDetector(
                      onTap: onTap,
                      child: SvgPicture.asset(
                        leadingIcon!,
                        colorFilter: labelColor != null
                            ? ColorFilter.mode(labelColor!, BlendMode.srcIn)
                            : null,
                      ),
                    )
                  : isPrifileVisible!
                      ? GestureDetector(
                          child: const ProfileAvatar(size: 40),
                        )
                      : const SizedBox(),
              leadingIcon != null || isPrifileVisible!
                  ? const SizedBox(width: 20)
                  : const SizedBox(),
              title != null
                  ? Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Title3(
                        text: title!,
                        color: labelColor,
                      ),
                    )
                  : child,
            ],
          ),
          if (isTrailingIcon == true) ...[
            if (trailingIcon != null)
              GestureDetector(
                onTap: onTapTrailing ?? onTap,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isFiltered == false
                        ? Colors.transparent
                        : Colors.deepPurple.shade50,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      SvgPicture.asset(
                        trailingIcon!,
                        colorFilter: isFiltered == false
                            ? ColorFilter.mode(labelColor ?? AppColors.dark100,
                                BlendMode.srcIn)
                            : const ColorFilter.mode(
                                AppColors.violet100, BlendMode.srcIn),
                      ),
                      if (isFiltered == true)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: const BoxDecoration(
                              color: AppColors.red100,
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Text(
                                "1",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  height: 1.2,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              )
            else
              GestureDetector(
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade50,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      SvgPicture.asset(
                        AppIcons.notificationIcon,
                        colorFilter: const ColorFilter.mode(
                            AppColors.violet100, BlendMode.srcIn),
                      ),
                      if (isFiltered == true)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: const BoxDecoration(
                              color: AppColors.red100,
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Text(
                                "1",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  height: 1.2,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
          if (!isBottonRequired! &&
              isTrailingIcon == false &&
              isStatButton == true)
            const StatButton(),
          if (isBottonRequired!)
            SizedBox(
                width: 78,
                height: 32,
                child: SolidButtonWidget(
                  label: "See All",
                  onPressed: onTap,
                  isCircle: true,
                  backgroundColor: AppColors.violet20,
                  labelColor: AppColors.violet100,
                )),
        ],
      ),
    );
  }
}
