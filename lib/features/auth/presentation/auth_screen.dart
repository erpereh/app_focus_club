import 'package:flutter/material.dart';

import '../application/auth_scope.dart';
import '../data/auth_repository.dart';
import '../../../navigation/app_router.dart';
import '../../../shared/widgets/focus_auth_scaffold.dart';
import '../../../shared/widgets/focus_brand_mark.dart';
import '../../../shared/widgets/focus_buttons.dart';
import '../../../shared/widgets/focus_glass_card.dart';
import '../../../shared/widgets/focus_segmented_control.dart';
import '../../../shared/widgets/focus_status_message.dart';
import '../../../shared/widgets/focus_text_field.dart';
import '../../../theme/app_theme.dart';

enum _AuthMode { login, register }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  _AuthMode _mode = _AuthMode.login;
  String? _statusMessage;
  FocusStatusType? _statusType;
  bool _privacyAccepted = false;
  bool _isLoginLoading = false;
  bool _isRegisterLoading = false;
  bool _isGoogleLoading = false;
  bool _isResendingVerification = false;
  String? _lastUnverifiedEmail;
  String? _lastUnverifiedPassword;

  @override
  void dispose() {
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _nameController.dispose();
    _registerEmailController.dispose();
    _phoneController.dispose();
    _registerPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isLogin = _mode == _AuthMode.login;

    return FocusAuthScaffold(
      child: FocusGlassCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Align(child: FocusBrandMark(icon: Icons.fitness_center)),
            const SizedBox(height: 18),
            Text(
              'Portal del Cliente',
              textAlign: TextAlign.center,
              style: textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Focus Club Vallecas',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            _AuthModeTabs(
              mode: _mode,
              onChanged: (mode) {
                setState(() {
                  _mode = mode;
                  _statusMessage = null;
                  _statusType = null;
                });
              },
            ),
            const SizedBox(height: 20),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: isLogin ? _buildLoginForm() : _buildRegisterForm(),
            ),
            if (_statusMessage != null && _statusType != null) ...[
              const SizedBox(height: 18),
              FocusStatusMessage(
                message: _statusMessage!,
                type: _statusType!,
                actionLabel: _statusType == FocusStatusType.warning
                    ? 'Reenviar email de verificacion'
                    : null,
                onAction: _statusType == FocusStatusType.warning
                    ? _showVerificationResent
                    : null,
              ),
            ],
            const SizedBox(height: 22),
            _DividerLabel(label: 'o'),
            const SizedBox(height: 18),
            FocusGoogleButton(
              isLoading: _isGoogleLoading,
              onPressed: _isBusy ? null : _submitGoogle,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _loginFormKey,
      child: Column(
        key: const ValueKey('login-form'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FocusTextField(
            label: 'Email',
            icon: Icons.mail_outline_rounded,
            controller: _loginEmailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: _validateEmail,
          ),
          const SizedBox(height: 16),
          FocusTextField(
            label: 'Contrasena',
            icon: Icons.lock_outline_rounded,
            controller: _loginPasswordController,
            obscureText: true,
            textInputAction: TextInputAction.done,
            validator: _validateRequiredPassword,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                Navigator.of(context).pushNamed(AppRouter.resetPassword);
              },
              child: const Text('Has olvidado tu contrasena?'),
            ),
          ),
          const SizedBox(height: 8),
          FocusPrimaryButton(
            label: 'Entrar',
            isLoading: _isLoginLoading,
            onPressed: _isBusy ? null : _submitLogin,
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterForm() {
    return Form(
      key: _registerFormKey,
      child: Column(
        key: const ValueKey('register-form'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FocusTextField(
            label: 'Nombre completo',
            icon: Icons.person_outline_rounded,
            controller: _nameController,
            textInputAction: TextInputAction.next,
            validator: (value) =>
                _required(value, 'Introduce tu nombre completo.'),
          ),
          const SizedBox(height: 16),
          FocusTextField(
            label: 'Email',
            icon: Icons.mail_outline_rounded,
            controller: _registerEmailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: _validateEmail,
          ),
          const SizedBox(height: 16),
          FocusTextField(
            label: 'Telefono',
            icon: Icons.phone_outlined,
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            validator: _validateSpanishPhone,
          ),
          const SizedBox(height: 16),
          FocusTextField(
            label: 'Contrasena',
            icon: Icons.lock_outline_rounded,
            controller: _registerPasswordController,
            obscureText: true,
            textInputAction: TextInputAction.next,
            validator: _validateStrongPassword,
          ),
          const SizedBox(height: 16),
          FocusTextField(
            label: 'Confirmar contrasena',
            icon: Icons.lock_reset_rounded,
            controller: _confirmPasswordController,
            obscureText: true,
            textInputAction: TextInputAction.done,
            validator: _validatePasswordConfirmation,
          ),
          const SizedBox(height: 10),
          FormField<bool>(
            validator: (_) => _privacyAccepted
                ? null
                : 'Debes aceptar la Politica de Privacidad.',
            builder: (field) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CheckboxListTile(
                    value: _privacyAccepted,
                    onChanged: (value) {
                      setState(() => _privacyAccepted = value ?? false);
                      field.didChange(value);
                    },
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: AppTheme.emerald,
                    title: Text(
                      'Acepto la Politica de Privacidad',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  if (field.hasError)
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Text(
                        field.errorText!,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: AppTheme.danger),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          FocusPrimaryButton(
            label: 'Crear Cuenta',
            isLoading: _isRegisterLoading,
            onPressed: _isBusy ? null : _submitRegister,
          ),
        ],
      ),
    );
  }

  bool get _isBusy =>
      _isLoginLoading ||
      _isRegisterLoading ||
      _isGoogleLoading ||
      _isResendingVerification;

  Future<void> _submitLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;
    setState(() {
      _isLoginLoading = true;
      _statusMessage = null;
      _statusType = null;
    });

    try {
      await AuthScope.of(context).signInWithEmail(
        email: _loginEmailController.text,
        password: _loginPasswordController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(AppRouter.dashboard);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _statusType = error is AuthFailure && error.code == 'email-not-verified'
            ? FocusStatusType.warning
            : FocusStatusType.error;
        _statusMessage = authErrorMessage(error);
        if (error is AuthFailure && error.code == 'email-not-verified') {
          _lastUnverifiedEmail = _loginEmailController.text;
          _lastUnverifiedPassword = _loginPasswordController.text;
        }
      });
    } finally {
      if (mounted) setState(() => _isLoginLoading = false);
    }
  }

  Future<void> _submitRegister() async {
    if (!_registerFormKey.currentState!.validate()) return;
    setState(() {
      _isRegisterLoading = true;
      _statusMessage = null;
      _statusType = null;
    });

    try {
      await AuthScope.of(context).registerWithEmail(
        name: _nameController.text,
        email: _registerEmailController.text,
        phone: _phoneController.text,
        password: _registerPasswordController.text,
      );
      if (!mounted) return;
      setState(() {
        _mode = _AuthMode.login;
        _statusType = FocusStatusType.success;
        _statusMessage =
            'Cuenta creada. Revisa tu email para completar la verificacion.';
        _loginEmailController.text = _registerEmailController.text.trim();
        _registerPasswordController.clear();
        _confirmPasswordController.clear();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _statusType = FocusStatusType.error;
        _statusMessage = authErrorMessage(error);
      });
    } finally {
      if (mounted) setState(() => _isRegisterLoading = false);
    }
  }

  Future<void> _submitGoogle() async {
    setState(() {
      _isGoogleLoading = true;
      _statusMessage = null;
      _statusType = null;
    });

    try {
      final result = await AuthScope.of(context).signInWithGoogle();
      if (!mounted) return;
      final route = result.status == GoogleAuthStatus.needsProfile
          ? AppRouter.completeGoogleProfile
          : AppRouter.dashboard;
      Navigator.of(context).pushReplacementNamed(route);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _statusType = FocusStatusType.error;
        _statusMessage = authErrorMessage(error);
      });
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  Future<void> _showVerificationResent() async {
    final email = _lastUnverifiedEmail;
    final password = _lastUnverifiedPassword;
    if (email == null || password == null) return;

    setState(() => _isResendingVerification = true);
    try {
      await AuthScope.of(
        context,
      ).resendEmailVerification(email: email, password: password);
      if (!mounted) return;
      setState(() {
        _statusType = FocusStatusType.success;
        _statusMessage = 'Email de verificacion reenviado.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _statusType = FocusStatusType.error;
        _statusMessage = authErrorMessage(error);
      });
    } finally {
      if (mounted) setState(() => _isResendingVerification = false);
    }
  }

  String? _validateEmail(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Introduce tu email.';
    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailPattern.hasMatch(text)) return 'Introduce un email valido.';
    return null;
  }

  String? _validateRequiredPassword(String? value) {
    return _required(value, 'Introduce tu contrasena.');
  }

  String? _validateSpanishPhone(String? value) {
    final normalized = (value ?? '').replaceAll(RegExp(r'[\s-]'), '');
    final phonePattern = RegExp(r'^(\+34)?[6789]\d{8}$');
    if (!phonePattern.hasMatch(normalized)) {
      return 'Introduce un telefono espanol valido.';
    }
    return null;
  }

  String? _validateStrongPassword(String? value) {
    final text = value ?? '';
    if (text.length < 8) {
      return 'La contrasena debe tener al menos 8 caracteres.';
    }
    if (!RegExp('[A-Za-z]').hasMatch(text) || !RegExp(r'\d').hasMatch(text)) {
      return 'La contrasena debe incluir una letra y un numero.';
    }
    return null;
  }

  String? _validatePasswordConfirmation(String? value) {
    if ((value ?? '').isEmpty) return 'Confirma tu contrasena.';
    if (value != _registerPasswordController.text) {
      return 'Las contrasenas no coinciden.';
    }
    return null;
  }

  String? _required(String? value, String message) {
    if ((value ?? '').trim().isEmpty) return message;
    return null;
  }
}

class _AuthModeTabs extends StatelessWidget {
  const _AuthModeTabs({required this.mode, required this.onChanged});

  final _AuthMode mode;
  final ValueChanged<_AuthMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return FocusSegmentedControl<_AuthMode>(
      options: const [
        FocusSegmentOption(value: _AuthMode.login, label: 'Iniciar Sesion'),
        FocusSegmentOption(value: _AuthMode.register, label: 'Registrarse'),
      ],
      selectedValue: mode,
      onChanged: onChanged,
    );
  }
}

class _DividerLabel extends StatelessWidget {
  const _DividerLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppTheme.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        const Expanded(child: Divider(color: AppTheme.border)),
      ],
    );
  }
}
