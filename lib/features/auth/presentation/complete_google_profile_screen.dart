import 'package:flutter/material.dart';

import '../../../navigation/app_router.dart';
import '../../../shared/widgets/focus_auth_scaffold.dart';
import '../../../shared/widgets/focus_brand_mark.dart';
import '../../../shared/widgets/focus_buttons.dart';
import '../../../shared/widgets/focus_glass_card.dart';
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
              FocusPrimaryButton(
                label: 'Guardar y Continuar',
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

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pushReplacementNamed(AppRouter.dashboard);
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
