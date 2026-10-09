import 'package:expensetracker/commons/components/button/app/base_button_widget.dart';
import 'package:expensetracker/commons/components/button/domain/entities/button_entity.dart';
import 'package:expensetracker/commons/constants/app_colors.dart';
import 'package:flutter/material.dart';

class SolidButtonWidget extends BaseButtonWidget {
  final Color? backgroundColor;
  SolidButtonWidget({
    required String label,
    Color? labelColor,
    String? iconPath,
    bool isLeadingIcon = true,
    bool isEnabled = true,
    this.backgroundColor = AppColors.violet100,
    required super.onPressed,
    super.isLoading = false,
    bool isCircle = false,
    super.key,
  }) : super(
            buttonEntity: ButtonEntity(
          label: label,
          labelColor: labelColor ?? AppColors.light100,
          iconPath: iconPath,
          isLeadingIcon: isLeadingIcon,
          isEnabled: isEnabled,
          isSolid: true,
          isCircle: isCircle,
        ));

  @override
  Widget buildButtonContent(BuildContext context) {
    return GestureDetector(
      onTap: buttonEntity.isEnabled ? onPressed : null,
      child: Container(
        height: 56.0,
        decoration: BoxDecoration(
          color: buttonEntity.isEnabled
              ? backgroundColor
              : backgroundColor?.withOpacity(0.5),
            borderRadius: BorderRadius.circular(
            buttonEntity.isCircle! ? 28.0 : 8.0,
          ),
        ),
        child: Center(
          child: FittedBox(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoading)
                  buildLoadingIndicator()
                else ...[
                  if (buttonEntity.isLeadingIcon) buildIcon(),
                  if (buttonEntity.iconPath != null && 
                  buttonEntity.label != ''
                  ) const SizedBox(width: 10),
                  buildLabel(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
