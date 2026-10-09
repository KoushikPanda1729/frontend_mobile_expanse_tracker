import 'package:expensetracker/commons/components/text_field/app/domain/entities/textfield_entity.dart';
import 'package:expensetracker/commons/components/text_field/app/viewmodels/base_textfield_viewmodel.dart';
import 'package:expensetracker/commons/components/text_field/app/viewmodels/email_textfield_viewmodel.dart';
import 'package:expensetracker/commons/components/text_field/app/views/base_textfield_widget.dart';

class EmailTextfieldWidget extends BaseTextfieldWidget {
  final String initialText;
  final bool hasClearTextButton;
  final String? leadingIconPath;
  final String? trailingIconPath;

  const EmailTextfieldWidget({
    super.key,
    this.initialText = "",
    this.hasClearTextButton = false,
    this.leadingIconPath,
    this.trailingIconPath,
    super.enabled,
    super.readOnly,
    super.focusNode,
    super.labelText,
    required super.onTextChanged,
    super.hintText = "e.g. john@example.com",
  });

  @override
  EmailTextFieldWidgetState createState() => EmailTextFieldWidgetState();
}

class EmailTextFieldWidgetState
    extends BaseTextfieldWidgetState<EmailTextfieldWidget> {
  @override
  BaseTextFieldViewModel createViewModel() {
    return EmailTextfieldViewmodel(
      TextFieldEntity(
          text: widget.initialText,
          hasClearTextButton: widget.hasClearTextButton,
          leadingIconPath: widget.leadingIconPath,
          trailingIconPath: widget.trailingIconPath,
          labelText: widget.labelText),
    );
  }
}
