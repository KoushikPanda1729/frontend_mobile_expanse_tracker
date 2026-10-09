import 'package:expensetracker/commons/components/text_field/app/domain/entities/validation_message_entity.dart';
import 'package:expensetracker/commons/constants/app_colors.dart';
import 'package:expensetracker/commons/constants/app_icons.dart';
import 'package:flutter/material.dart';

class PasswordValidator {
  static bool isValid(String password) {
    return password.length >= 6;
  }

  static List<ValidationMessage> validate(String password) {
    final List<ValidationMessage> validationMessages = [];
    final bool isEmpty = password.isEmpty;

    Color getColor(bool isValid) {
      if (isEmpty) return Colors.black;
      return isValid ? AppColors.green100 : AppColors.red100;
    }

    final bool minLengthError = password.length < 6;

    validationMessages.add(
      ValidationMessage(
        'Password should be at least 6 characters',
        isEmpty
            ? AppIcons.warningIcon
            : (minLengthError ? AppIcons.warningIcon : AppIcons.checkIcon),
        isValid: !minLengthError && !isEmpty,
        color: getColor(!minLengthError && !isEmpty),
      ),
    );

    return validationMessages;
  }
}
