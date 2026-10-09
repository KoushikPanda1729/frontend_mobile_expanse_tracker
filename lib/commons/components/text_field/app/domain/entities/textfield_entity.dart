import 'package:expensetracker/commons/components/text_field/app/domain/entities/helper_message_entity.dart';
import 'package:expensetracker/commons/components/text_field/app/domain/entities/validation_message_entity.dart';
import 'package:flutter/services.dart';

class TextFieldEntity {
  final String text;
  final bool obscureText;
  final bool hasClearTextButton;
  final String? labelText;
  final String? leadingIconPath;
  final double? leadingIconSize;
  final String? trailingIconPath;
  final List<HelperMessage>? helperMessages;
  final List<ValidationMessage> validationMessages;
  final bool isDirty;
  final List<TextInputFormatter>? inputFormatters;

  TextFieldEntity({
    this.text = '',
    this.obscureText = false,
    this.hasClearTextButton = false,
    this.labelText,
    this.leadingIconPath,
    this.trailingIconPath,
    this.helperMessages = const [],
    this.validationMessages = const [],
    this.isDirty = false,
    this.leadingIconSize = 16.0,
    this.inputFormatters = const [],
  });

  // The copyWith method
  TextFieldEntity copyWith({
    String? text,
    bool? obscureText,
    bool? hasClearTextButton,
    String? labelText,
    String? leadingIconPath,
    String? trailingIconPath,
    List<HelperMessage>? helperMessages,
    List<ValidationMessage>? validationMessages,
    bool? isDirty,
    final double? leadingIconSize,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFieldEntity(
      text: text ?? this.text,
      obscureText: obscureText ?? this.obscureText,
      hasClearTextButton: hasClearTextButton ?? this.hasClearTextButton,
      labelText: labelText ?? this.labelText,
      leadingIconPath: leadingIconPath ?? this.leadingIconPath,
      trailingIconPath: trailingIconPath ?? this.trailingIconPath,
      helperMessages: helperMessages ?? this.helperMessages,
      validationMessages: validationMessages ?? this.validationMessages,
      isDirty: isDirty ?? this.isDirty,
      leadingIconSize: leadingIconSize ?? this.leadingIconSize,
      inputFormatters: inputFormatters ?? this.inputFormatters,
    );
  }
}
