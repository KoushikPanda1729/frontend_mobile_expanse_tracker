import 'package:expensetracker/pages/login/app/viewmodels/login_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// UI-only: no backend yet. loginUser accepts any non-empty credentials.
class LoginViewModel extends StateNotifier<LoginPageState> {
  LoginViewModel() : super(LoginPageState());

  void updateEmail(String email) {
    state = state.copyWith(emailId: email);
  }

  void updatePassword(String password) {
    state = state.copyWith(password: password);
  }

  void errorMessage(String errorMessage) {
    state = state.copyWith(errorMessage: errorMessage);
  }

  bool isPasswordValid() {
    return state.password != null && state.password!.isNotEmpty;
  }

  Future<bool> loginUser(String? emailId, String? password) async {
    return emailId != null &&
        password != null &&
        emailId.isNotEmpty &&
        password.isNotEmpty;
  }
}
