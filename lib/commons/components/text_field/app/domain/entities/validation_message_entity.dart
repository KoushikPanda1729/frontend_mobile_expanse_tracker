import 'package:expensetracker/commons/constants/app_colors.dart';
import 'package:flutter/material.dart';

class ValidationMessage {
  final String message;
  final String iconPath;
  final bool isValid;
  final Color color; // Add color property

  ValidationMessage(
    this.message,
    this.iconPath, {
    this.isValid = false,
    this.color = AppColors.red100,
  });

  @override
  String toString() {
    return 'ValidationMessage(message: $message, iconPath: $iconPath, isValid: $isValid, color: $color)';
  }
}
