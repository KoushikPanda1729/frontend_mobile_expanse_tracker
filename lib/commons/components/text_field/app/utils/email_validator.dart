import 'package:expensetracker/commons/components/text_field/app/domain/entities/validation_message_entity.dart';
import 'package:expensetracker/commons/constants/app_colors.dart';
import 'package:expensetracker/commons/constants/app_icons.dart';

class EmailValidator {
  EmailValidator(String email);
  static bool isValid(String email) {
    if (email.isEmpty) return false;
    const emailPattern =
        r'^([a-zA-Z0-9_\.\-])+\@(([a-zA-Z0-9\-])+\.)+([a-zA-Z0-9]{2,4})+$';
    return RegExp(emailPattern).hasMatch(email);
  }

  static List<ValidationMessage> validate(String email) {
    final List<ValidationMessage> validationMessages = [];
    if (email.isEmpty) {
      validationMessages.add(ValidationMessage(
          "Message can not be empty", AppIcons.warningIcon,
          isValid: false, color: AppColors.red100));
    } else if (!isValid(email)) {
      validationMessages.add(ValidationMessage(
          "Please Enter a Valid Email", AppIcons.warningIcon,
          color: AppColors.red100));
    }
    return validationMessages;
  }
}
