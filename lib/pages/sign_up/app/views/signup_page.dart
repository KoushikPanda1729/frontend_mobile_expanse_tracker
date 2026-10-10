import 'package:expensetracker/commons/components/button/app/solid_button_widget.dart';
import 'package:expensetracker/commons/constants/app_colors.dart';
import 'package:expensetracker/data/countries.dart';
import 'package:expensetracker/data/api.dart';
import 'package:expensetracker/data/auth.dart';
import 'package:expensetracker/pages/auth/auth_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SignupPage extends ConsumerStatefulWidget {
  const SignupPage({super.key});

  @override
  ConsumerState<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends ConsumerState<SignupPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  Country _country = india;
  final _password = TextEditingController();
  bool _agree = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  /// 0..4: length, upper case, digit, symbol.
  int get _strength {
    final p = _password.text;
    return [
      p.length >= 8,
      RegExp(r'[A-Z]').hasMatch(p),
      RegExp(r'\d').hasMatch(p),
      RegExp(r'[^A-Za-z0-9]').hasMatch(p),
    ].where((x) => x).length;
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (!_agree) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please accept the Terms and Privacy Policy')));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(authProvider.notifier).register(
          name: _name.text.trim(),
          countryCode: _country.dial,
          phone: _phone.text.trim(),
          password: _password.text);
      if (!mounted) return;
      context.goNamed('home');
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content:
              Text(e is ApiException ? e.message : 'Could not create the account.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _strength;
    final labels = ['Too short', 'Weak', 'Okay', 'Good', 'Strong'];
    final colors = [
      AppColors.red100,
      AppColors.red100,
      AppColors.yellow100,
      AppColors.green80,
      AppColors.green100,
    ];
    final hasPw = _password.text.isNotEmpty;

    return AuthShell(
      title: 'Create account',
      subtitle: 'Track every rupee in one place. It takes a minute.',
      bottom: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Already have an account?  ',
              style: TextStyle(color: Colors.grey[700])),
          GestureDetector(
            onTap: () => context.pushReplacement('/login'),
            child: const Text('Sign in',
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
                AuthField(
                  label: 'Name',
                  hint: 'e.g. Koushik Panda',
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  capitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Enter your name' : null,
                ),
                const SizedBox(height: 18),
                PhoneField(
                  controller: _phone,
                  country: _country,
                  onCountryChanged: (c) => setState(() => _country = c),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 18),
                PasswordField(
                  hint: 'At least 8 characters',
                  controller: _password,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  onChanged: (_) => setState(() {}),
                  validator: (v) => (v ?? '').length < 8
                      ? 'Use at least 8 characters'
                      : null,
                ),
              ],
            ),
          ),
        ),
        if (hasPw) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < 4; i++)
                Expanded(
                  child: Container(
                    height: 4,
                    margin: EdgeInsets.only(right: i < 3 ? 6 : 0),
                    decoration: BoxDecoration(
                      color: i < s ? colors[s] : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              Text(labels[s],
                  style: TextStyle(
                      color: colors[s],
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Mix upper case, numbers and symbols for a stronger password.',
              style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        ],
        const SizedBox(height: 18),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _agree = !_agree),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: _agree,
                  activeColor: AppColors.violet100,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                  onChanged: (v) => setState(() => _agree = v ?? false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(color: Colors.grey[700], height: 1.4),
                    children: const [
                      TextSpan(text: 'I agree to the '),
                      TextSpan(
                        text: 'Terms of Service',
                        style: TextStyle(
                            color: AppColors.violet100,
                            fontWeight: FontWeight.w600),
                      ),
                      TextSpan(text: ' and '),
                      TextSpan(
                        text: 'Privacy Policy',
                        style: TextStyle(
                            color: AppColors.violet100,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SolidButtonWidget(
          label: _busy ? 'Creating account...' : 'Create account',
          onPressed: _busy ? null : _submit,
        ),
      ],
    );
  }
}
