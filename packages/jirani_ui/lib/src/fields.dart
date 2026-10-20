import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A field for a fixed-length number such as a sign-in code or a PIN.
class DigitsField extends StatelessWidget {
  const DigitsField({
    super.key,
    required this.controller,
    required this.label,
    this.length = 6,
    this.obscure = false,
    this.errorText,
    this.onSubmitted,
    this.autofocus = true,
  });

  final TextEditingController controller;
  final String label;
  final int length;
  final bool obscure;
  final String? errorText;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      obscureText: obscure,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      autofillHints: obscure ? null : const [AutofillHints.oneTimeCode],
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(length),
      ],
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.headlineSmall
          ?.copyWith(letterSpacing: 12, fontWeight: FontWeight.w800),
      decoration: InputDecoration(labelText: label, errorText: errorText, counterText: ''),
      onSubmitted: onSubmitted,
    );
  }
}
