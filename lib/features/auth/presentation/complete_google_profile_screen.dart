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

class CompleteGoogleProfileScreen extends StatefulWidget {
  const CompleteGoogleProfileScreen({super.key});

  @override
  State<CompleteGoogleProfileScreen> createState() =>
      _CompleteGoogleProfileScreenState();
}

class _CompleteGoogleProfileScreenState
    extends State<CompleteGoogleProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: 'Cliente Focus');
  final _phoneController = TextEditingController();
  bool _didHydrateName = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didHydrateName) return;
    _didHydrateName = true;
    final displayName = AuthScope.of(context).currentSession?.displayName;
    if (displayName != null && displayName.trim().isNotEmpty) {
      _nameController.text = displayName.trim();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
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
              const Align(child: FocusBrandMark(icon: Icons.person_rounded)),
              const SizedBox(height: 20),
              Text(
                'Completa tu Perfil',
                textAlign: TextAlign.center,
                style: textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              Text(
                'Necesitamos algunos datos mas',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 26),
              FocusTextField(
                label: 'Nombre',
                icon: Icons.person_outline_rounded,
                controller: _nameController,
                textInputAction: TextInputAction.next,
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Introduce tu nombre.'
                    : null,
              ),
              const SizedBox(height: 16),
              FocusTextField(
                label: 'Telefono',
                icon: Icons.phone_outlined,
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                validator: _validateSpanishPhone,
              ),
              const SizedBox(height: 24),
              if (_errorMessage != null) ...[
                FocusStatusMessage(
                  message: _errorMessage!,
                  type: FocusStatusType.error,
                ),
                const SizedBox(height: 18),
              ],
              FocusPrimaryButton(
                label: 'Guardar y Continuar',
                isLoading: _isLoading,
                onPressed: _submit,
              ),
              const SizedBox(height: 12),
              FocusGhostButton(
                label: 'Volver',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final authRepository = AuthScope.of(context);
    final session = authRepository.currentSession;
    if (session == null) {
      setState(() {
        _errorMessage = 'La sesion ha caducado. Vuelve a iniciar sesion.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await authRepository.updateSafeProfileFields(
        uid: session.uid,
        name: _nameController.text,
        phone: _phoneController.text,
        photoUrl: session.photoUrl,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(AppRouter.dashboard);
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _validateSpanishPhone(String? value) {
    final normalized = (value ?? '').replaceAll(RegExp(r'[\s-]'), '');
    final phonePattern = RegExp(r'^(\+34)?[6789]\d{8}$');
    if (!phonePattern.hasMatch(normalized)) {
      return 'Introduce un telefono espanol valido.';
    }
    return null;
  }
}
