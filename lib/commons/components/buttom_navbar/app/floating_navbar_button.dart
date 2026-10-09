import 'dart:math' show max;

import 'package:expensetracker/commons/constants/app_colors.dart';
import 'package:expensetracker/commons/constants/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

/// Height of the floating nav pill, and the gap kept below it.
const double kNavHeight = 64;
double navBottomMargin(BuildContext c) =>
    max(MediaQuery.of(c).padding.bottom, 12);

/// Centre "+" button. Tapping it dims the screen and fans out labelled actions.
class FloatingActionButtonWidget extends StatelessWidget {
  final String iconPath;
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color iconColor;

  const FloatingActionButtonWidget({
    super.key,
    required this.iconPath,
    required this.onTap,
    this.backgroundColor = AppColors.violet100,
    this.iconColor = Colors.white,
  });

  static const double _size = 52;

  void _openMenu(BuildContext context) {
    final router = GoRouter.of(context);
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, __) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        final w = MediaQuery.of(ctx).size.width;
        // the + button sits in the middle of the nav pill
        final fabBottom = navBottomMargin(ctx) + kNavHeight / 2 - _size / 2;

        Widget action(String label, String icon, Color color, String route,
            double dx, double lift) {
          return Positioned(
            bottom: fabBottom + _size + 16 + lift,
            left: w / 2 + dx - 45,
            width: 90,
            child: ScaleTransition(
              scale: curved,
              child: FadeTransition(
                opacity: anim,
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(ctx).pop();
                    router.push(route);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(0.5),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(15),
                        child: SvgPicture.asset(icon,
                            colorFilter: const ColorFilter.mode(
                                Colors.white, BlendMode.srcIn)),
                      ),
                      const SizedBox(height: 8),
                      Text(label,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              decoration: TextDecoration.none)),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return Stack(
          children: [
            action('Income', AppIcons.incomeIcon, AppColors.green100,
                '/income', -88, 0),
            action('Expense', AppIcons.expenseIcon, AppColors.red100,
                '/expenses', 88, 0),
            action('Transfer', AppIcons.currencyExchangeIcon, AppColors.blue100,
                '/transfer', 0, 84),
            // close button drawn over the real + button
            Positioned(
              bottom: fabBottom,
              left: w / 2 - _size / 2,
              child: GestureDetector(
                onTap: () => Navigator.of(ctx).pop(),
                child: RotationTransition(
                  turns: Tween(begin: 0.0, end: 0.125).animate(anim),
                  child: _circle(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _circle() => Container(
        height: _size,
        width: _size,
        decoration:
            BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
        child: Padding(
          padding: const EdgeInsets.all(_size * 0.1),
          child: SvgPicture.asset(
            iconPath,
            colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        onTap();
        _openMenu(context);
      },
      child: _circle(),
    );
  }
}
