import 'package:expensetracker/pages/login/app/viewmodels/login_state.dart';
import 'package:expensetracker/pages/login/app/viewmodels/login_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final loginProvider = StateNotifierProvider<LoginViewModel, LoginPageState>(
  (ref) => LoginViewModel(),
);
