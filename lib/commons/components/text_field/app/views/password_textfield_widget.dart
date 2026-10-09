import 'package:expensetracker/commons/components/text_field/app/domain/entities/textfield_entity.dart';
import 'package:expensetracker/commons/components/text_field/app/viewmodels/base_textfield_viewmodel.dart';
import 'package:expensetracker/commons/components/text_field/app/viewmodels/password_textfield_viewmodel.dart';
import 'package:expensetracker/commons/constants/app_colors.dart';
import 'package:expensetracker/commons/constants/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'base_textfield_widget.dart';

class PasswordTextFieldWidget extends BaseTextfieldWidget {
  final String initialText;
  final String? leadingIconPath;
  final String? trailingIconPath;
  final bool enableValidation;
  final bool showVisibilityToggle;

  const PasswordTextFieldWidget({
    super.key,
    this.initialText = '',
    this.leadingIconPath,
    this.trailingIconPath,
    this.showVisibilityToggle = true,
    this.enableValidation = true,
    bool? enabled,
    bool? readOnly,
    required super.onTextChanged,
    super.labelText,
    super.hintText = 'Password',
  });

  @override
  PasswordTextFieldWidgetState createState() => PasswordTextFieldWidgetState();
}

class PasswordTextFieldWidgetState
    extends BaseTextfieldWidgetState<PasswordTextFieldWidget> {
  @override
  BaseTextFieldViewModel createViewModel() {
    return PasswordTextFieldViewModel(
      TextFieldEntity(
        text: widget.initialText,
        labelText: widget.labelText,
        obscureText: true,
        leadingIconPath: widget.leadingIconPath,
        trailingIconPath: widget.showVisibilityToggle
            ? AppIcons.eyeClose
            : widget.trailingIconPath,
      ),
      enableValidation: widget.enableValidation,
    );
  }

  @override
  Widget? buildTrailingIcon(TextFieldEntity state) {
    {
      final isValid =
          widget.enableValidation ? viewModel.isValid(state.text) : false;

      if (widget.showVisibilityToggle) {
        return Padding(
          padding:
              const EdgeInsetsDirectional.only(end: 16.0), // Add right padding
          child: Row(
            mainAxisAlignment: widget.enableValidation
                ? MainAxisAlignment.start
                : MainAxisAlignment.end,
            children: [
              if (widget.enableValidation) ...[
                SizedBox(
                  width: 18.0,
                  height: 18.0,
                  child: isValid
                      ? SvgPicture.asset(
                          AppIcons.checkIcon,
                          height: 18.0,
                          width: 18.0,
                          colorFilter: const ColorFilter.mode(
                            AppColors.green100,
                            BlendMode.srcIn,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 8.0),
              ],
              GestureDetector(
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
            ],
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
