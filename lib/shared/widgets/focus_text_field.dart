import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class FocusTextField extends StatefulWidget {
  const FocusTextField({
    required this.label,
    required this.controller,
    super.key,
    this.hint,
    this.icon,
    this.keyboardType,
    this.validator,
    this.textInputAction,
    this.obscureText = false,
    this.minLines,
    this.maxLines = 1,
  });

  final String label;
  final String? hint;
  final IconData? icon;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final int? minLines;
  final int maxLines;

  @override
  State<FocusTextField> createState() => _FocusTextFieldState();
}

class _FocusTextFieldState extends State<FocusTextField> {
  late bool _isObscured = widget.obscureText;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      keyboardType: widget.keyboardType,
      validator: widget.validator,
      textInputAction: widget.textInputAction,
      obscureText: _isObscured,
      minLines: widget.obscureText ? 1 : widget.minLines,
      maxLines: widget.obscureText ? 1 : widget.maxLines,
      style: const TextStyle(color: AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        prefixIcon: widget.icon == null ? null : Icon(widget.icon, size: 20),
        suffixIcon: widget.obscureText
            ? IconButton(
                tooltip: _isObscured
                    ? 'Mostrar contrasena'
                    : 'Ocultar contrasena',
                onPressed: () => setState(() => _isObscured = !_isObscured),
                icon: Icon(
                  _isObscured
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                ),
              )
            : null,
      ),
    );
  }
}
