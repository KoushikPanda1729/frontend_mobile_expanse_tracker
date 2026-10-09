import 'package:expensetracker/commons/components/text_field/app/domain/entities/textfield_entity.dart';
import 'package:expensetracker/commons/components/text_field/app/domain/entities/validation_message_entity.dart';
import 'package:expensetracker/commons/components/text_field/app/utils/email_validator.dart';
import 'package:expensetracker/commons/components/text_field/app/viewmodels/base_textfield_viewmodel.dart';

class EmailTextfieldViewmodel extends BaseTextFieldViewModel {
  EmailTextfieldViewmodel(super.initialState);
  @override
  List<ValidationMessage> validateText(TextFieldEntity state) {
    if (state.isDirty) {
      return EmailValidator.validate(state.text);
    }
    return [];
  }
}
