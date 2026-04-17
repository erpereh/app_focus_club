import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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
import '../data/avatar_storage_repository.dart';
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
  final _imagePicker = ImagePicker();
  String? _profileUid;
  String? _profilePhotoUrl;
  Uint8List? _avatarPreviewBytes;
  Uint8List? _avatarUploadBytes;
  String? _avatarExtension;
  String? _avatarContentType;
  bool _photoRemoved = false;
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
    _syncProfile();
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
    final session = AuthScope.of(context).currentSession;

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
                  _AvatarEditor(
                    profile: profile,
                    previewBytes: _avatarPreviewBytes,
                    photoRemoved: _photoRemoved,
                    onPickAvatar: _pickAvatar,
                    onRemoveAvatar: _removeAvatar,
                  ),
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
                  if (session?.canChangePassword == true) ...[
                    const SizedBox(height: 18),
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
    if (profile == null) return;
    if (profile.uid != _profileUid) {
      _profileUid = profile.uid;
      _nameController.text = profile.name;
      _phoneController.text = profile.phone ?? '';
      _clearLocalAvatarState();
    }
    if (profile.photoUrl != _profilePhotoUrl && !_isSaving) {
      _profilePhotoUrl = profile.photoUrl;
      _clearLocalAvatarState();
    }
  }

  Future<void> _pickAvatar() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (!mounted) return;
    setState(() {
      _avatarPreviewBytes = bytes;
      _avatarUploadBytes = bytes;
      _avatarExtension = _extensionFor(image.name, image.mimeType);
      _avatarContentType = image.mimeType ?? 'image/jpeg';
      _photoRemoved = false;
      _statusMessage = null;
    });
  }

  void _removeAvatar() {
    setState(() {
      _avatarPreviewBytes = null;
      _avatarUploadBytes = null;
      _avatarExtension = null;
      _avatarContentType = null;
      _photoRemoved = true;
      _statusMessage = null;
    });
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
      final currentPhotoUrl = widget.state.profile?.photoUrl ?? '';
      String? nextPhotoUrl = currentPhotoUrl.isEmpty ? null : currentPhotoUrl;
      final avatarUploadBytes = _avatarUploadBytes;
      if (avatarUploadBytes != null) {
        final avatarRepository = FirebaseAvatarStorageRepository();
        final extension = _avatarExtension ?? 'jpg';
        nextPhotoUrl = await avatarRepository.uploadAvatar(
          uid: uid,
          fileName:
              'profile-${DateTime.now().millisecondsSinceEpoch}.$extension',
          bytes: avatarUploadBytes,
          contentType: _avatarContentType ?? 'image/jpeg',
        );
        await avatarRepository.deleteAvatarByUrl(currentPhotoUrl);
      } else if (_photoRemoved) {
        final avatarRepository = FirebaseAvatarStorageRepository();
        await avatarRepository.deleteAvatarByUrl(currentPhotoUrl);
        nextPhotoUrl = '';
      }

      await authRepository.updateSafeProfileFields(
        uid: uid,
        name: _nameController.text,
        phone: _phoneController.text,
        photoUrl: nextPhotoUrl,
      );
      if (_passwordController.text.isNotEmpty) {
        await authRepository.updatePassword(_passwordController.text);
      }
      if (!mounted) return;
      _passwordController.clear();
      setState(() {
        _statusMessage = 'Perfil actualizado correctamente.';
        _statusType = FocusStatusType.success;
        _avatarUploadBytes = null;
        _avatarExtension = null;
        _avatarContentType = null;
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

  void _clearLocalAvatarState() {
    _avatarPreviewBytes = null;
    _avatarUploadBytes = null;
    _avatarExtension = null;
    _avatarContentType = null;
    _photoRemoved = false;
  }

  String _extensionFor(String fileName, String? contentType) {
    final rawExtension = fileName.split('.').last.toLowerCase();
    if (rawExtension != fileName && rawExtension.length <= 5) {
      return rawExtension == 'jpeg' ? 'jpg' : rawExtension;
    }
    return switch (contentType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      'image/heic' => 'heic',
      _ => 'jpg',
    };
  }
}

class _AvatarEditor extends StatelessWidget {
  const _AvatarEditor({
    required this.profile,
    required this.previewBytes,
    required this.photoRemoved,
    required this.onPickAvatar,
    required this.onRemoveAvatar,
  });

  final UserProfile? profile;
  final Uint8List? previewBytes;
  final bool photoRemoved;
  final VoidCallback onPickAvatar;
  final VoidCallback onRemoveAvatar;

  @override
  Widget build(BuildContext context) {
    final hasPreview = previewBytes != null;
    final hasRemoteAvatar = !photoRemoved && profile?.hasPhoto == true;
    final hasAvatar = hasPreview || hasRemoteAvatar;
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
                      child: hasPreview
                          ? Image.memory(
                              previewBytes!,
                              width: 92,
                              height: 92,
                              fit: BoxFit.cover,
                            )
                          : Image.network(
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
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onPickAvatar,
                icon: const Icon(Icons.photo_camera_outlined, size: 18),
                label: const Text('Cambiar foto'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: hasAvatar ? onRemoveAvatar : null,
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Eliminar foto'),
              ),
            ),
          ],
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
