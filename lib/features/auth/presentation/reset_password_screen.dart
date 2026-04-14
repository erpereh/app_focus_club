import 'package:flutter/material.dart';

import '../application/auth_scope.dart';
import '../data/auth_repository.dart';
import '../../../navigation/app_router.dart';
import '../../../shared/widgets/focus_auth_scaffold.dart';
import '../../../shared/widgets/focus_brand_mark.dart';
import '../../../shared/widgets/focus_buttons.dart';
import '../../../shared/widgets/focus_glass_card.dart';
import '../../../shared/widgets/focus_status_message.dart';
import '../../../shared/widgets/focus_text_field.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  String? _successMessage;
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return FocusAuthScaffold(
      child: FocusGlassCard(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Align(child: FocusBrandMark(icon: Icons.key_rounded)),
              const SizedBox(height: 20),
              Text(
                'Recuperar Contrasena',
                textAlign: TextAlign.center,
                style: textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              Text(
                'Introduce tu email y te enviaremos un enlace de recuperacion.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 26),
              FocusTextField(
                label: 'Email',
                icon: Icons.mail_outline_rounded,
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                validator: _validateEmail,
              ),
              if (_successMessage != null) ...[
                const SizedBox(height: 18),
                FocusStatusMessage(
                  message: _successMessage!,
                  type: FocusStatusType.success,
                ),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 18),
                FocusStatusMessage(
                  message: _errorMessage!,
                  type: FocusStatusType.error,
                ),
              ],
              const SizedBox(height: 22),
              FocusPrimaryButton(
                label: 'Enviar enlace',
                isLoading: _isLoading,
                onPressed: _isLoading ? null : _submit,
              ),
              const SizedBox(height: 12),
              FocusGhostButton(
                label: 'Volver al inicio de sesion',
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed(AppRouter.auth);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _successMessage = null;
      _errorMessage = null;
    });
    try {
      await AuthScope.of(context).sendPasswordResetEmail(_emailController.text);
      if (!mounted) return;
      setState(() {
        _successMessage = 'Enlace enviado. Revisa tu bandeja de entrada.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _validateEmail(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Introduce tu email.';
    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailPattern.hasMatch(text)) return 'Introduce un email valido.';
    return null;
  }
}
