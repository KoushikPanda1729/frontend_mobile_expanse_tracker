import 'package:expensetracker/commons/components/text_field/app/domain/entities/textfield_entity.dart';
import 'package:expensetracker/commons/components/text_field/app/domain/entities/validation_message_entity.dart';
import 'package:expensetracker/commons/components/text_field/app/utils/password_multi_validator.dart';
import 'package:expensetracker/commons/components/text_field/app/viewmodels/base_textfield_viewmodel.dart';
import 'package:expensetracker/commons/constants/app_colors.dart';
import 'package:flutter/material.dart';

enum PasswordStrength { veryWeak, weak, medium, strong, none }

class PasswordTextFieldMultiValidationViewModel extends BaseTextFieldViewModel {
  final bool showVisibilityToggle;

  PasswordTextFieldMultiValidationViewModel(
    super.initialState, {
    this.showVisibilityToggle = true,
  });

  PasswordStrength calculateStrength(TextFieldEntity state) {
    if (state.text.isEmpty) return PasswordStrength.none;

    final validations = validateText(state);
    final passedValidations = validations.where((v) => v.isValid).length;

    if (passedValidations <= 2) return PasswordStrength.veryWeak;
    if (passedValidations <= 4) return PasswordStrength.weak;
    if (passedValidations <= 5) return PasswordStrength.medium;
    return PasswordStrength.strong;
  }

  Color getStrengthSegmentColor(PasswordStrength strength, int segmentIndex) {
    switch (strength) {
      case PasswordStrength.veryWeak:
        return segmentIndex == 0 ? AppColors.red100 : AppColors.light100;
      case PasswordStrength.weak:
        return segmentIndex <= 1 ? AppColors.red100 : AppColors.light100;
      case PasswordStrength.medium:
        return segmentIndex <= 2 ? AppColors.yellow100 : AppColors.light100;
      case PasswordStrength.strong:
        return AppColors.green100;
      case PasswordStrength.none:
        return AppColors.light100;
    }
  }

  Color getStrengthTextColor(PasswordStrength strength) {
    switch (strength) {
      case PasswordStrength.veryWeak:
        return AppColors.red100;
      case PasswordStrength.weak:
        return AppColors.red60;
      case PasswordStrength.medium:
        return AppColors.red80;
      case PasswordStrength.strong:
        return AppColors.green100;
      case PasswordStrength.none:
        return AppColors.light100;
    }
  }

  String getStrengthText(PasswordStrength strength) {
    switch (strength) {
      case PasswordStrength.veryWeak:
        return 'Very weak';
      case PasswordStrength.weak:
        return 'Weak';
      case PasswordStrength.medium:
        return 'Medium';
      case PasswordStrength.strong:
        return 'Strong';
      case PasswordStrength.none:
        return '';
    }
  }

  @override
  bool isValid(String text) {
    return PasswordMultiValidator.isValid(text);
  }

  @override
  List<ValidationMessage> validateText(TextFieldEntity state) {
    return PasswordMultiValidator.validate(state.text);
  }
}
