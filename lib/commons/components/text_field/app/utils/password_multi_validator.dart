import 'package:expensetracker/commons/components/text_field/app/domain/entities/validation_message_entity.dart';
import 'package:expensetracker/commons/constants/app_colors.dart';
import 'package:expensetracker/commons/constants/app_icons.dart';
import 'package:flutter/material.dart';

class PasswordMultiValidator {
  static bool isValid(String password) {
    if (password.isEmpty) return false;

    final bool hasMinLength = password.length >= 5;
    final bool hasMaxLength = password.length <= 15;
    final bool hasUpperCase = RegExp(r'[A-Z]').hasMatch(password);
    final bool hasLowerCase = RegExp(r'[a-z]').hasMatch(password);
    final bool hasNumber = RegExp(r'\d').hasMatch(password);
    final bool hasSymbol = RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password);

    return hasMinLength &&
        hasMaxLength &&
        hasUpperCase &&
        hasLowerCase &&
        hasNumber &&
        hasSymbol;
  }

  static List<ValidationMessage> validate(String password) {
    final List<ValidationMessage> validationMessages = [];
    final bool isEmpty = password.isEmpty;
    Color getColor(bool isValid) {
      if (isEmpty) {
        return AppColors.dark50;
      } else if (isValid) {
        return AppColors.green100;
      } else {
        return AppColors.red100;
      }
    }

    final minLengthError = password.length < 5;
    validationMessages.add(ValidationMessage(
      'Minimum 5 characters in length',
      isEmpty
          ? AppIcons.warningIcon
          : (minLengthError ? AppIcons.closeIcon : AppIcons.checkIcon),
      isValid: !minLengthError && !isEmpty,
      color: getColor(!minLengthError && !isEmpty),
    ));

    final maxLengthError = password.length > 15;
    validationMessages.add(ValidationMessage(
      'Maximum 15 characters in length',
      isEmpty
          ? AppIcons.warningIcon
          : (maxLengthError ? AppIcons.closeIcon : AppIcons.checkIcon),
      isValid: !maxLengthError && !isEmpty,
      color: getColor(!maxLengthError && !isEmpty),
    ));

    final upperCaseError = !RegExp(r'[A-Z]').hasMatch(password);
    validationMessages.add(ValidationMessage(
      'Has atleast 1 upper case character(A-Z)',
      isEmpty
          ? AppIcons.warningIcon
          : (upperCaseError ? AppIcons.closeIcon : AppIcons.checkIcon),
      isValid: !upperCaseError && !isEmpty,
      color: getColor(!upperCaseError && !isEmpty),
    ));

    final lowerCaseError = !RegExp(r'[a-z]').hasMatch(password);
    validationMessages.add(ValidationMessage(
      'Has atleast 1 lower case character(A-Z)',
      isEmpty
          ? AppIcons.warningIcon
          : (lowerCaseError ? AppIcons.closeIcon : AppIcons.checkIcon),
      isValid: !lowerCaseError && !isEmpty,
      color: getColor(!lowerCaseError && !isEmpty),
    ));

    final numberError = !RegExp(r'\d').hasMatch(password);
    validationMessages.add(ValidationMessage(
      'Has atleast 1 number [0-9]',
      isEmpty
          ? AppIcons.warningIcon
          : (numberError ? AppIcons.closeIcon : AppIcons.checkIcon),
      isValid: !numberError && !isEmpty,
      color: getColor(!numberError && !isEmpty),
    ));
    final symbolError = !RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password);
    validationMessages.add(ValidationMessage(
      'Has atleast 1 symbol',
      isEmpty
          ? AppIcons.warningIcon
          : (symbolError ? AppIcons.closeIcon : AppIcons.checkIcon),
      isValid: !symbolError && !isEmpty,
      color: getColor(!symbolError && !isEmpty),
    ));

    return validationMessages;
  }
}
