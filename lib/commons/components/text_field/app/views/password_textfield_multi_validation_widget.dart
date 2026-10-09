import 'package:expensetracker/commons/components/text_field/app/domain/entities/textfield_entity.dart';
import 'package:expensetracker/commons/components/text_field/app/viewmodels/base_textfield_viewmodel.dart';
import 'package:expensetracker/commons/components/text_field/app/viewmodels/password_textfield_multi_validation_viewmodel.dart';
import 'package:expensetracker/commons/constants/app_icons.dart';
import 'package:expensetracker/commons/text/app/views/custom_text_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'base_textfield_widget.dart';

class PasswordTextFieldMultiValidationWidget extends BaseTextfieldWidget {
  final String initialText;
  final String? leadingIconPath;
  final String? trailingIconPath;
  final bool showVisibilityToggle;

  const PasswordTextFieldMultiValidationWidget({
    super.key,
    this.initialText = '',
    this.leadingIconPath,
    this.trailingIconPath,
    this.showVisibilityToggle = true,
    bool? enabled,
    bool? readOnly,
    required super.onTextChanged,
    super.hintText = "Password",
    super.labelText,
  });
  @override
  PasswordTextFieldMultiValidationWidgetState createState() =>
      PasswordTextFieldMultiValidationWidgetState();
}

class PasswordTextFieldMultiValidationWidgetState
    extends BaseTextfieldWidgetState<PasswordTextFieldMultiValidationWidget> {
  @override
  BaseTextFieldViewModel createViewModel() {
    return PasswordTextFieldMultiValidationViewModel(
      TextFieldEntity(
        text: widget.initialText,
        labelText: widget.labelText,
        obscureText: true,
        leadingIconPath: widget.leadingIconPath,
        trailingIconPath: widget.showVisibilityToggle
            ? AppIcons.eyeClose
            : widget.trailingIconPath,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextFieldEntity>(
      valueListenable: viewModel,
      builder: (context, state, child) {
        if (controller.text != state.text) {
          controller.text = state.text;
          controller.selection = TextSelection.fromPosition(
            TextPosition(offset: controller.text.length),
          );
        }

        final validationMessages = viewModel.validateText(state);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildTextField(state),
            const SizedBox(height: 12.0),
            buildPasswordStrengthIndicator(state),
            const SizedBox(height: 20.0),
            if (validationMessages.isNotEmpty)
              buildValidationMessages(validationMessages),
          ],
        );
      },
    );
  }

  Widget buildPasswordStrengthIndicator(TextFieldEntity state) {
    final passwordViewModel =
        viewModel as PasswordTextFieldMultiValidationViewModel;
    final strength = passwordViewModel.calculateStrength(state);
    final strengthText = passwordViewModel.getStrengthText(strength);
    final strengthTextColor = passwordViewModel.getStrengthTextColor(strength);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Body3(text: 'Password strength'),
            if (strengthText.isNotEmpty)
              Body3(
                text: strengthText,
                color: strengthTextColor,
              ),
          ],
        ),
        const SizedBox(height: 8.0),
        SizedBox(
          height: 4.0,
          child: Row(
            children: [
              // First segment
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(2.0),
                      right: Radius.circular(2.0),
                    ),
                    color:
                        passwordViewModel.getStrengthSegmentColor(strength, 0),
                  ),
                  margin: const EdgeInsets.only(right: 3),
                ),
              ),
              // Second segment
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(2.0),
                      right: Radius.circular(2.0),
                    ),
                    color:
                        passwordViewModel.getStrengthSegmentColor(strength, 1),
                  ),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                ),
              ),
              // Third segment
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(2.0),
                      right: Radius.circular(2.0),
                    ),
                    color:
                        passwordViewModel.getStrengthSegmentColor(strength, 2),
                  ),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                ),
              ),
              // Fourth segment
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(2.0),
                      right: Radius.circular(2.0),
                    ),
                    color:
                        passwordViewModel.getStrengthSegmentColor(strength, 3),
                  ),
                  margin: const EdgeInsets.only(left: 3),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget? buildTrailingIcon(TextFieldEntity state) {
    if (state.text.isNotEmpty) {
      if (viewModel is PasswordTextFieldMultiValidationViewModel &&
          (viewModel as PasswordTextFieldMultiValidationViewModel)
              .showVisibilityToggle) {
        return Padding(
          padding: const EdgeInsetsDirectional.only(end: 16.0),
          child: GestureDetector(
            onTap: viewModel.toggleObscureText,
            child: SizedBox(
              width: 18.0,
              height: 18.0,
              child: SvgPicture.asset(
                state.obscureText ? AppIcons.eyeClose : AppIcons.showIcon,
                height: 18.0,
                width: 18.0,
              ),
            ),
          ),
        );
      } else if (state.trailingIconPath != null) {
        return Padding(
          padding: const EdgeInsetsDirectional.only(end: 16.0),
          child: GestureDetector(
            onTap: state.obscureText ? viewModel.toggleObscureText : null,
            child: SizedBox(
              width: 18.0,
              height: 18.0,
              child: SvgPicture.asset(
                state.trailingIconPath!,
                height: 18.0,
                width: 18.0,
              ),
            ),
          ),
        );
      }
    }
    return null;
  }
}
