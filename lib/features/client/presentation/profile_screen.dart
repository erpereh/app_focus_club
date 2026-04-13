import 'package:flutter/material.dart';

import '../../../shared/widgets/focus_buttons.dart';
import '../../../shared/widgets/focus_glass_card.dart';
import '../../../shared/widgets/focus_section_header.dart';
import '../../../shared/widgets/focus_status_message.dart';
import '../../../shared/widgets/focus_text_field.dart';
import '../../../theme/app_theme.dart';
import '../data/mock_client_data.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(
    text: MockClientData.profile.name,
  );
  final _phoneController = TextEditingController(
    text: MockClientData.profile.phone,
  );
  final _passwordController = TextEditingController();
  bool _hasAvatar = MockClientData.profile.hasAvatar;
  String? _statusMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          Text('Mi Perfil', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(
            'Actualiza tus datos de cliente.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          FocusGlassCard(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AvatarEditor(
                    hasAvatar: _hasAvatar,
                    initials: MockClientData.profile.initials,
                    onChangePhoto: () {
                      setState(() {
                        _hasAvatar = true;
                        _statusMessage = 'Foto actualizada en modo demo.';
                      });
                    },
                    onRemovePhoto: _hasAvatar
                        ? () {
                            setState(() {
                              _hasAvatar = false;
                              _statusMessage = 'Foto eliminada en modo demo.';
                            });
                          }
                        : null,
                  ),
                  const SizedBox(height: 22),
                  FocusTextField(
                    label: 'Nombre visible',
                    icon: Icons.person_outline_rounded,
                    controller: _nameController,
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? 'Introduce tu nombre.'
                        : null,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 14),
                  FocusTextField(
                    label: 'Telefono',
                    icon: Icons.phone_outlined,
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    validator: _validateSpanishPhone,
                    textInputAction: TextInputAction.next,
                  ),
                  if (MockClientData.profile.usesPasswordProvider) ...[
                    const SizedBox(height: 14),
                    FocusTextField(
                      label: 'Nueva contrasena',
                      icon: Icons.lock_outline_rounded,
                      controller: _passwordController,
                      obscureText: true,
                      validator: _validateOptionalPassword,
                      textInputAction: TextInputAction.done,
                    ),
                  ],
                  if (_statusMessage != null) ...[
                    const SizedBox(height: 16),
                    FocusStatusMessage(
                      message: _statusMessage!,
                      type: FocusStatusType.success,
                    ),
                  ],
                  const SizedBox(height: 20),
                  FocusPrimaryButton(
                    label: 'Guardar cambios',
                    onPressed: _saveProfile,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _saveProfile() {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _statusMessage = 'Perfil actualizado correctamente.';
      _passwordController.clear();
    });
  }

  String? _validateSpanishPhone(String? value) {
    final normalized = (value ?? '').replaceAll(RegExp(r'[\s-]'), '');
    final phonePattern = RegExp(r'^(\+34)?[6789]\d{8}$');
    if (!phonePattern.hasMatch(normalized)) {
      return 'Introduce un telefono espanol valido.';
    }
    return null;
  }

  String? _validateOptionalPassword(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return null;
    if (text.length < 8) {
      return 'La contrasena debe tener al menos 8 caracteres.';
    }
    if (!RegExp('[A-Za-z]').hasMatch(text) || !RegExp(r'\d').hasMatch(text)) {
      return 'La contrasena debe incluir una letra y un numero.';
    }
    return null;
  }
}

class _AvatarEditor extends StatelessWidget {
  const _AvatarEditor({
    required this.hasAvatar,
    required this.initials,
    required this.onChangePhoto,
    required this.onRemovePhoto,
  });

  final bool hasAvatar;
  final String initials;
  final VoidCallback onChangePhoto;
  final VoidCallback? onRemovePhoto;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: hasAvatar
                ? AppTheme.emerald.withValues(alpha: 0.12)
                : AppTheme.input,
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            border: Border.all(
              color: hasAvatar
                  ? AppTheme.emerald.withValues(alpha: 0.32)
                  : AppTheme.border,
            ),
          ),
          child: SizedBox(
            width: 92,
            height: 92,
            child: Center(
              child: hasAvatar
                  ? Text(
                      initials,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: AppTheme.emerald,
                            fontWeight: FontWeight.w900,
                          ),
                    )
                  : const Icon(
                      Icons.person_outline_rounded,
                      color: AppTheme.textSecondary,
                      size: 34,
                    ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        FocusSectionHeader(title: 'Avatar'),
        const SizedBox(height: 10),
        FocusGhostButton(
          label: hasAvatar ? 'Cambiar foto' : 'Subir foto',
          icon: Icons.photo_camera_outlined,
          onPressed: onChangePhoto,
        ),
        const SizedBox(height: 10),
        FocusGhostButton(
          label: 'Eliminar foto',
          icon: Icons.delete_outline_rounded,
          onPressed: onRemovePhoto,
        ),
      ],
    );
  }
}
