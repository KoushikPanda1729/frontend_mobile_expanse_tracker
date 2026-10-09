import 'package:expensetracker/commons/components/button/app/solid_button_widget.dart';
import 'package:expensetracker/commons/constants/app_colors.dart';
import 'package:expensetracker/data/countries.dart';
import 'package:expensetracker/pages/auth/auth_widgets.dart';
import 'package:expensetracker/pages/login/app/providers/login_page_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _phone = TextEditingController();
  Country _country = india;
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    final vm = ref.read(loginProvider.notifier);
    final number = '${_country.dial}${_phone.text.trim()}';
    vm.updateEmail(number); // the view model still calls this field "email"
    vm.updatePassword(_password.text);
    // UI only for now: loginUser() accepts any non-empty credentials.
    final ok = await vm.loginUser(number, _password.text);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) context.goNamed('home');
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: 'Welcome back',
      subtitle: 'Sign in to see where your money went this month.',
      bottom: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("Don't have an account?  ",
              style: TextStyle(color: Colors.grey[700])),
          GestureDetector(
            onTap: () => context.pushReplacement('/signup'),
            child: const Text('Sign up',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: AppColors.violet100)),
          ),
        ],
      ),
      children: [
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              children: [
                PhoneField(
                  controller: _phone,
                  country: _country,
                  onCountryChanged: (c) => setState(() => _country = c),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 18),
                PasswordField(
                  controller: _password,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  validator: (v) =>
                      (v ?? '').isEmpty ? 'Enter your password' : null,
                  onSubmitted: (_) => _submit(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        SolidButtonWidget(
          label: _busy ? 'Signing in...' : 'Sign in',
          onPressed: _busy ? null : _submit,
        ),
      ],
    );
  }
}
