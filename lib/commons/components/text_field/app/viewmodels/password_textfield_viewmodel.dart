import 'package:expensetracker/commons/components/text_field/app/domain/entities/textfield_entity.dart';
import 'package:expensetracker/commons/components/text_field/app/domain/entities/validation_message_entity.dart';
import 'package:expensetracker/commons/components/text_field/app/utils/password_validator.dart';
import 'package:expensetracker/commons/components/text_field/app/viewmodels/base_textfield_viewmodel.dart';

class PasswordTextFieldViewModel extends BaseTextFieldViewModel {
  final bool showVisibilityToggle;
  final bool enableValidation;

  PasswordTextFieldViewModel(
    super.initialState, {
    this.enableValidation = true,
    this.showVisibilityToggle = true,
  });
  @override
  List<ValidationMessage> validateText(TextFieldEntity state) {
    if (!enableValidation) return [];
    return PasswordValidator.validate(state.text);
  }

  @override
  bool isValid(String text) {
    if (!enableValidation) return true;
    return PasswordValidator.isValid(text);
  }
}
