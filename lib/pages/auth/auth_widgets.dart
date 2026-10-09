import 'package:expensetracker/commons/constants/app_colors.dart';
import 'package:expensetracker/data/countries.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Shared frame for the login and sign-up screens.
class AuthShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;
  final Widget bottom; // pinned link, e.g. "Don't have an account? Sign up"

  const AuthShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    required this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // plain header: back arrow, title, subtitle
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    onPressed: () => context.canPop()
                        ? context.pop()
                        : context.goNamed('onboarding'),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 12, top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                fontSize: 28, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        Text(subtitle,
                            style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 15,
                                height: 1.4)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: children,
                      ),
                    ),
                  ),
                  if (!keyboardOpen)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20, top: 4),
                      child: bottom,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Text field with its label above: filled, rounded, violet when focused.
class AuthField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscure;
  final Widget? suffix;
  final Iterable<String>? autofillHints;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextCapitalization capitalization;

  const AuthField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.keyboardType,
    this.textInputAction,
    this.obscure = false,
    this.suffix,
    this.autofillHints,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.capitalization = TextCapitalization.none,
  });

  OutlineInputBorder _border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: c, width: w),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: capitalization,
          autofillHints: autofillHints,
          validator: validator,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[500]),
            filled: true,
            fillColor: Colors.grey.withOpacity(0.07),
            suffixIcon: suffix,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: _border(Colors.transparent),
            enabledBorder: _border(Colors.transparent),
            focusedBorder: _border(AppColors.violet100, 1.5),
            errorBorder: _border(AppColors.red100),
            focusedErrorBorder: _border(AppColors.red100, 1.5),
          ),
        ),
      ],
    );
  }
}

/// Password field with a show/hide eye.
class PasswordField extends StatefulWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;

  const PasswordField({
    super.key,
    this.label = 'Password',
    this.hint = 'Enter your password',
    required this.controller,
    this.textInputAction,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.autofillHints,
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _hide = true;

  @override
  Widget build(BuildContext context) {
    return AuthField(
      label: widget.label,
      hint: widget.hint,
      controller: widget.controller,
      obscure: _hide,
      textInputAction: widget.textInputAction,
      validator: widget.validator,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      autofillHints: widget.autofillHints,
      suffix: IconButton(
        icon: Icon(_hide ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: Colors.grey[600], size: 20),
        onPressed: () => setState(() => _hide = !_hide),
      ),
    );
  }
}

/// Phone number field with a country picker (flag + dial code) in front of it.
class PhoneField extends StatefulWidget {
  final TextEditingController controller;
  final Country country;
  final ValueChanged<Country> onCountryChanged;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final String label;

  const PhoneField({
    super.key,
    required this.controller,
    required this.country,
    required this.onCountryChanged,
    this.textInputAction,
    this.onSubmitted,
    this.label = 'Phone number',
  });

  @override
  State<PhoneField> createState() => _PhoneFieldState();
}

class _PhoneFieldState extends State<PhoneField> {
  String? _validate(String? v) {
    final d = (v ?? '').replaceAll(RegExp(r'\D'), '');
    final c = widget.country;
    if (d.isEmpty) return 'Enter your phone number';
    if (d.length < c.minLen || d.length > c.maxLen) {
      final need = c.minLen == c.maxLen
          ? '${c.minLen}'
          : '${c.minLen}-${c.maxLen}';
      return 'Enter a $need digit number for ${c.name}';
    }
    return null;
  }

  Future<void> _pick() async {
    final picked = await showCountryPicker(context, widget.country);
    if (picked != null) {
      widget.onCountryChanged(picked);
      // length rules changed, re-check what is already typed
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.country;
    OutlineInputBorder border(Color col, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: col, width: w),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.controller,
          keyboardType: TextInputType.phone,
          textInputAction: widget.textInputAction,
          autofillHints: const [AutofillHints.telephoneNumberNational],
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(c.maxLen),
          ],
          validator: _validate,
          onFieldSubmitted: widget.onSubmitted,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          style: const TextStyle(fontSize: 16, letterSpacing: 0.5),
          decoration: InputDecoration(
            hintText: 'Phone number',
            hintStyle: TextStyle(color: Colors.grey[500]),
            filled: true,
            fillColor: Colors.grey.withOpacity(0.07),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            prefixIcon: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _pick,
              child: Padding(
                padding: const EdgeInsets.only(left: 14, right: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(c.flag, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 6),
                    Text(c.dial,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 16)),
                    Icon(Icons.keyboard_arrow_down,
                        size: 20, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Container(width: 1, height: 22, color: Colors.grey[300]),
                  ],
                ),
              ),
            ),
            border: border(Colors.transparent),
            enabledBorder: border(Colors.transparent),
            focusedBorder: border(AppColors.violet100, 1.5),
            errorBorder: border(AppColors.red100),
            focusedErrorBorder: border(AppColors.red100, 1.5),
          ),
        ),
      ],
    );
  }
}

/// Bottom sheet with a search box and the country list.
Future<Country?> showCountryPicker(BuildContext context, Country selected) {
  return showModalBottomSheet<Country>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheet) {
      var query = '';
      return StatefulBuilder(
        builder: (_, setS) {
          final q = query.toLowerCase();
          final list = [
            for (final c in countries)
              if (q.isEmpty ||
                  c.name.toLowerCase().contains(q) ||
                  c.dial.contains(q) ||
                  c.iso.toLowerCase() == q)
                c
          ];
          return SizedBox(
            height: MediaQuery.of(sheet).size.height * 0.75,
            child: Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(sheet).viewInsets.bottom),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  const Text('Select country',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      onChanged: (v) => setS(() => query = v),
                      decoration: InputDecoration(
                        hintText: 'Search country or code',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.grey.withOpacity(0.08),
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: list.isEmpty
                        ? const Center(child: Text('No country found'))
                        : ListView.builder(
                            itemCount: list.length,
                            itemBuilder: (_, i) {
                              final c = list[i];
                              final sel = c.iso == selected.iso;
                              return ListTile(
                                leading: Text(c.flag,
                                    style: const TextStyle(fontSize: 26)),
                                title: Text(c.name,
                                    style: TextStyle(
                                        fontWeight: sel
                                            ? FontWeight.w700
                                            : FontWeight.w500)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(c.dial,
                                        style: TextStyle(
                                            color: Colors.grey[700],
                                            fontWeight: FontWeight.w600)),
                                    if (sel) ...[
                                      const SizedBox(width: 8),
                                      const Icon(Icons.check,
                                          color: AppColors.violet100),
                                    ],
                                  ],
                                ),
                                onTap: () => Navigator.pop(sheet, c),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
