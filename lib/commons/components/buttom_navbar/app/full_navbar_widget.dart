import 'package:expensetracker/commons/components/buttom_navbar/app/floating_navbar_button.dart';
import 'package:expensetracker/commons/constants/app_colors.dart';
import 'package:expensetracker/commons/constants/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class BottomNavBarWidget extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const BottomNavBarWidget({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  @override
  Widget build(BuildContext context) {
    // floating pill: no dead space under the labels, clear of the screen corners
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 6, 16, navBottomMargin(context)),
      child: Container(
        height: kNavHeight,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: NavItem(
                iconPath: AppIcons.homeIcon,
                label: 'Home',
                isSelected: selectedIndex == 0,
                onTap: () => onItemTapped(0),
              ),
            ),
            Expanded(
              child: NavItem(
                iconPath: AppIcons.transactionIcon,
                label: 'Transactions',
                isSelected: selectedIndex == 1,
                onTap: () => onItemTapped(1),
              ),
            ),
            SizedBox(
              width: 68,
              child: Center(
                child: FloatingActionButtonWidget(
                  iconPath: AppIcons.plusIcon,
                  onTap: () {},
                ),
              ),
            ),
            Expanded(
              child: NavItem(
                iconPath: AppIcons.pieChartIcon,
                label: 'Budget',
                isSelected: selectedIndex == 2,
                onTap: () => onItemTapped(2),
              ),
            ),
            Expanded(
              child: NavItem(
                iconPath: AppIcons.userIcon,
                label: 'Profile',
                isSelected: selectedIndex == 3,
                onTap: () => onItemTapped(3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NavItem extends StatelessWidget {
  final String iconPath;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const NavItem({
    super.key,
    required this.iconPath,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppColors.violet100 : AppColors.dark25;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.violet20 : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SvgPicture.asset(
              iconPath,
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              height: 22,
              width: 22,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
