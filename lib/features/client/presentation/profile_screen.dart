import 'package:flutter/material.dart';

import '../../auth/application/auth_scope.dart';
import '../../auth/data/auth_repository.dart';
import '../../../navigation/app_router.dart';
import '../../../shared/widgets/focus_buttons.dart';
import '../../../shared/widgets/focus_glass_card.dart';
import '../../../shared/widgets/focus_section_header.dart';
import '../../../shared/widgets/focus_status_message.dart';
import '../../../shared/widgets/focus_text_field.dart';
import '../../../theme/app_theme.dart';
import '../application/client_portal_view_model.dart';
import '../domain/portal_models.dart';
import '../widgets/appointment_display.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({required this.state, super.key});

  final ClientPortalState state;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _profileUid;
  String? _statusMessage;
  FocusStatusType _statusType = FocusStatusType.success;
  bool _isSaving = false;
  bool _isSigningOut = false;

  @override
  void initState() {
    super.initState();
    _syncProfile();
  }

  @override
  void didUpdateWidget(ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.profile?.uid != widget.state.profile?.uid) {
      _syncProfile();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.state.profile;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 42),
        children: [
          Text('Mi Perfil', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          Text(
            'Actualiza tus datos de cliente.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 30),
          FocusGlassCard(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AvatarEditor(profile: profile),
                  const SizedBox(height: 28),
                  if (profile != null) ...[
                    _ReadonlyLine(label: 'Email', value: profile.email),
                    const SizedBox(height: 18),
                  ],
                  FocusTextField(
                    label: 'Nombre visible',
                    icon: Icons.person_outline_rounded,
                    controller: _nameController,
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? 'Introduce tu nombre.'
                        : null,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 18),
                  FocusTextField(
                    label: 'Telefono',
                    icon: Icons.phone_outlined,
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    validator: _validateSpanishPhone,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 18),
                  FocusTextField(
                    label: 'Nueva contrasena',
                    icon: Icons.lock_outline_rounded,
                    controller: _passwordController,
                    obscureText: true,
                    validator: _validateOptionalPassword,
                    textInputAction: TextInputAction.done,
                  ),
                  if (_statusMessage != null) ...[
                    const SizedBox(height: 20),
                    FocusStatusMessage(
                      message: _statusMessage!,
                      type: _statusType,
                    ),
                  ],
                  const SizedBox(height: 26),
                  FocusPrimaryButton(
                    label: 'Guardar cambios',
                    onPressed: _isSaving ? null : _saveProfile,
                  ),
                  const SizedBox(height: 12),
                  FocusGhostButton(
                    label: 'Cerrar sesion',
                    icon: Icons.logout_rounded,
                    onPressed: _isSigningOut ? null : _signOut,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _syncProfile() {
    final profile = widget.state.profile;
    if (profile == null || profile.uid == _profileUid) return;
    _profileUid = profile.uid;
    _nameController.text = profile.name;
    _phoneController.text = profile.phone ?? '';
  }

  Future<void> _signOut() async {
    setState(() => _isSigningOut = true);
    await AuthScope.of(context).signOut();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRouter.auth, (route) => false);
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final authRepository = AuthScope.of(context);
    final uid = authRepository.currentSession?.uid;
    if (uid == null) {
      setState(() {
        _statusMessage = 'Inicia sesion para actualizar el perfil.';
        _statusType = FocusStatusType.error;
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _statusMessage = null;
    });
    try {
      await authRepository.updateSafeProfileFields(
        uid: uid,
        name: _nameController.text,
        phone: _phoneController.text,
        photoUrl: widget.state.profile?.photoUrl,
      );
      if (_passwordController.text.isNotEmpty) {
        await authRepository.updatePassword(_passwordController.text);
      }
      if (!mounted) return;
      _passwordController.clear();
      setState(() {
        _statusMessage = 'Perfil actualizado correctamente.';
        _statusType = FocusStatusType.success;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _statusMessage = authErrorMessage(error);
        _statusType = FocusStatusType.error;
      });
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
  const _AvatarEditor({required this.profile});

  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    final hasAvatar = profile?.hasPhoto == true;
    return Column(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: hasAvatar ? AppTheme.surfaceElevated : AppTheme.input,
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            border: Border.all(
              color: hasAvatar
                  ? AppTheme.emerald.withValues(alpha: 0.34)
                  : AppTheme.border,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.24),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: SizedBox(
            width: 92,
            height: 92,
            child: Center(
              child: hasAvatar
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                      child: Image.network(
                        profile!.photoUrl!,
                        width: 92,
                        height: 92,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Text(
                      profile?.displayInitials ?? '?',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: AppTheme.emerald,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        FocusSectionHeader(title: 'Avatar'),
        const SizedBox(height: 14),
        const FocusStatusMessage(
          message:
              'La gestion de avatar no esta disponible todavia en la app movil.',
          type: FocusStatusType.warning,
        ),
      ],
    );
  }
}

class _ReadonlyLine extends StatelessWidget {
  const _ReadonlyLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.input,
        borderRadius: BorderRadius.circular(AppTheme.radiusInput),
        border: Border.all(color: AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 5),
            Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
