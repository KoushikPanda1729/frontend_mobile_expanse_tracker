import 'package:expensetracker/commons/components/button/domain/entities/button_entity.dart';
import 'package:expensetracker/commons/text/app/views/custom_text_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

abstract class BaseButtonWidget extends StatelessWidget {
  final ButtonEntity buttonEntity;
  final VoidCallback? onPressed;
  final bool isLoading;

  const BaseButtonWidget({
    required this.buttonEntity,
    required this.onPressed,
    this.isLoading = false,
    super.key,
  });
  Widget buildButtonContent(BuildContext context);

  @override
  Widget build(BuildContext context) {
    return buildButtonContent(context);
  }

  Widget buildIcon() {
    return buttonEntity.iconPath != null
        ? SvgPicture.asset(
            buttonEntity.iconPath!,
            height: 32,
            width: 32,
            colorFilter: ColorFilter.mode(
              (buttonEntity.iconColor != null
                  ? buttonEntity.iconColor!
                      .withOpacity(buttonEntity.isEnabled ? 1.0 : 0.5)
                  : (buttonEntity.labelColor != null
                      ? buttonEntity.labelColor!
                          .withOpacity(buttonEntity.isEnabled ? 1.0 : 0.5)
                      : Colors.black
                          .withOpacity(buttonEntity.isEnabled ? 1.0 : 0.5))),
              BlendMode.srcIn,
            ),
          )
        : const SizedBox.shrink();
  }

  Widget buildLabel() {
    final labelOpacity = buttonEntity.isEnabled ? 1.0 : 0.5;

    final adjustedColor = buttonEntity.labelColor?.withOpacity(labelOpacity) ??
        Colors.black.withOpacity(labelOpacity);

    return Body3(text: buttonEntity.label, color: adjustedColor);
  }

  Widget buildLoadingIndicator({Color? color}) {
    return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
              color ?? buttonEntity.labelColor ?? Colors.white),
        ));
  }
}
