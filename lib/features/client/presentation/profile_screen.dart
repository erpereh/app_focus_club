import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../auth/application/auth_scope.dart';
import '../../auth/data/auth_repository.dart';
import '../../../navigation/app_router.dart';
import '../application/portal_scope.dart';
import '../../../shared/widgets/focus_buttons.dart';
import '../../../shared/widgets/focus_section_header.dart';
import '../../../shared/widgets/focus_status_message.dart';
import '../../../shared/widgets/focus_text_field.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_text_size.dart';
import '../application/client_portal_view_model.dart';
import '../data/avatar_storage_repository.dart';
import '../data/portal_repository.dart';
import '../data/push_notification_service.dart';
import '../domain/portal_models.dart';
import '../widgets/appointment_display.dart';

final _privacyPolicyUri = Uri.parse(
  'https://focusclub.es/politica-de-privacidad',
);

Future<bool> _launchExternalUrl(Uri uri) {
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

class ProfileScreen extends StatefulWidget {
  ProfileScreen({
    required this.state,
    super.key,
    FirebasePushNotificationService? pushNotificationService,
    Future<bool> Function(Uri)? urlLauncher,
  }) : _urlLauncher = urlLauncher ?? _launchExternalUrl,
       pushNotificationService =
           pushNotificationService ?? FirebasePushNotificationService.instance;

  final ClientPortalState state;
  final FirebasePushNotificationService pushNotificationService;
  final Future<bool> Function(Uri) _urlLauncher;

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
  bool _isDeletingAccount = false;
  bool _isUpdatingPushNotifications = false;

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
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 150),
        children: [
          const _ProfileHeader(),
          const SizedBox(height: 22),
          _ProfileCard(
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
                    _PushNotificationsSwitch(
                      enabled: profile.pushNotificationsEnabled,
                      isUpdating: _isUpdatingPushNotifications,
                      onChanged: _isUpdatingPushNotifications
                          ? null
                          : _setPushNotificationsEnabled,
                    ),
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
          const SizedBox(height: 22),
          const FocusSectionHeader(title: 'Ajustes'),
          const SizedBox(height: 14),
          const _ProfileCard(child: _TextSizeSetting()),
          const SizedBox(height: 22),
          const FocusSectionHeader(title: 'Legal'),
          const SizedBox(height: 14),
          _LegalLinkRow(onTap: _openPrivacyPolicy),
          const SizedBox(height: 22),
          _DangerZone(
            isDeleting: _isDeletingAccount,
            onDeleteAccount: profile == null || _isDeletingAccount
                ? null
                : () => _showDeleteAccountDialog(profile.email),
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

  Future<void> _openPrivacyPolicy() async {
    var launched = false;
    try {
      launched = await widget._urlLauncher(_privacyPolicyUri);
    } catch (_) {
      launched = false;
    }
    if (launched || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No se ha podido abrir la política de privacidad.'),
      ),
    );
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
    final authRepository = AuthScope.of(context);
    final navigator = Navigator.of(context);
    setState(() => _isSigningOut = true);
    await FirebasePushNotificationService.instance.stop();
    await authRepository.signOut();
    if (!mounted) return;
    navigator.pushNamedAndRemoveUntil(AppRouter.auth, (route) => false);
  }

  Future<void> _showDeleteAccountDialog(String email) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: !_isDeletingAccount,
      builder: (_) =>
          _DeleteAccountDialog(email: email, onConfirm: _deleteOwnAccount),
    );
  }

  Future<void> _deleteOwnAccount() async {
    final portalRepository = PortalScope.of(context);
    final authRepository = AuthScope.of(context);
    final navigator = Navigator.of(context);

    setState(() {
      _isDeletingAccount = true;
      _statusMessage = null;
    });

    try {
      await portalRepository.deleteOwnAccount();
      await FirebasePushNotificationService.instance.stop();
      await authRepository.signOut();
      if (!mounted) return;
      navigator.pushNamedAndRemoveUntil(AppRouter.auth, (route) => false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _statusMessage = deleteOwnAccountErrorMessage(error);
        _statusType = FocusStatusType.error;
      });
      rethrow;
    } finally {
      if (mounted) {
        setState(() => _isDeletingAccount = false);
      }
    }
  }

  Future<void> _setPushNotificationsEnabled(bool enabled) async {
    final uid = AuthScope.of(context).currentSession?.uid;
    if (uid == null) {
      setState(() {
        _statusMessage = 'Inicia sesion para actualizar las notificaciones.';
        _statusType = FocusStatusType.error;
      });
      return;
    }

    final repository = PortalScope.of(context);
    setState(() {
      _isUpdatingPushNotifications = true;
      _statusMessage = null;
    });

    try {
      if (enabled) {
        await widget.pushNotificationService.enableForUser(
          uid: uid,
          repository: repository,
        );
        if (!mounted) return;
        setState(() {
          _statusMessage = 'Notificaciones activadas.';
          _statusType = FocusStatusType.success;
        });
      } else {
        await widget.pushNotificationService.disableForUser(
          uid: uid,
          repository: repository,
        );
        if (!mounted) return;
        setState(() {
          _statusMessage = 'Notificaciones desactivadas.';
          _statusType = FocusStatusType.success;
        });
      }
    } on PushNotificationPermissionDenied catch (error) {
      if (!mounted) return;
      setState(() {
        _statusMessage = _pushNotificationErrorMessage(error, enabled);
        _statusType = FocusStatusType.error;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _statusMessage = _pushNotificationErrorMessage(error, enabled);
        _statusType = FocusStatusType.error;
      });
    } finally {
      if (mounted) {
        setState(() => _isUpdatingPushNotifications = false);
      }
    }
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

  String _pushNotificationErrorMessage(Object error, bool enabling) {
    if (enabling && defaultTargetPlatform == TargetPlatform.iOS) {
      return 'No hemos podido activar las notificaciones. Revisa los permisos del iPhone e intentalo de nuevo.';
    }
    if (error is PushNotificationPermissionDenied) {
      return 'Activa el permiso de notificaciones para recibir avisos.';
    }
    return 'No hemos podido actualizar las notificaciones. Intentalo de nuevo.';
  }
}

class _TextSizeSetting extends StatelessWidget {
  const _TextSizeSetting();

  @override
  Widget build(BuildContext context) {
    final current = AppTextSizeScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Tamaño de texto', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Text(
          'Aumenta el tamaño de texto en toda la aplicación.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: SegmentedButton<AppTextSize>(
            segments: const [
              ButtonSegment(
                value: AppTextSize.defaultSize,
                label: Text('Predeterminado', key: Key('text-size-default')),
              ),
              ButtonSegment(
                value: AppTextSize.large,
                label: Text('Grande', key: Key('text-size-large')),
              ),
            ],
            selected: {current},
            showSelectedIcon: false,
            expandedInsets: EdgeInsets.zero,
            onSelectionChanged: (selection) {
              AppTextSizeScope.set(context, selection.single);
            },
          ),
        ),
      ],
    );
  }
}

class _LegalLinkRow extends StatelessWidget {
  const _LegalLinkRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(AppTheme.radiusInput);
    return Material(
      color: AppTheme.input.withValues(alpha: 0.58),
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: BorderSide(color: AppTheme.borderStrong.withValues(alpha: 0.22)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        key: const Key('privacy-policy-link'),
        link: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: ListTile(
            onTap: onTap,
            dense: true,
            visualDensity: VisualDensity.compact,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            minLeadingWidth: 20,
            horizontalTitleGap: 12,
            leading: const Icon(
              Icons.shield_outlined,
              color: AppTheme.emerald,
              size: 20,
            ),
            title: Text(
              'Política de privacidad',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textSecondary,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mi Perfil',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Actualiza tus datos de cliente.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppTheme.textSecondary.withValues(alpha: 0.88),
          ),
        ),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.surfaceGlass,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: AppTheme.borderStrong.withValues(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(22), child: child),
    );
  }
}

class _DangerZone extends StatelessWidget {
  const _DangerZone({required this.isDeleting, required this.onDeleteAccount});

  final bool isDeleting;
  final VoidCallback? onDeleteAccount;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.danger.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: AppTheme.danger,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Zona de peligro',
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.copyWith(color: AppTheme.danger),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Eliminar tu cuenta borrara el acceso y limpiara tus datos personales.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: OutlinedButton.icon(
                key: const Key('delete-account-button'),
                onPressed: onDeleteAccount,
                icon: isDeleting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_forever_rounded, size: 18),
                label: Text(
                  isDeleting ? 'Eliminando cuenta...' : 'Eliminar cuenta',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.danger,
                  side: BorderSide(
                    color: AppTheme.danger.withValues(alpha: 0.64),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({required this.email, required this.onConfirm});

  final String email;
  final Future<void> Function() onConfirm;

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isSubmitting = false;

  bool get _emailMatches => _emailController.text.trim() == widget.email;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('Eliminar cuenta definitivamente'),
      actionsOverflowDirection: VerticalDirection.down,
      actionsOverflowButtonSpacing: 8,
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Esta accion eliminara tu cuenta y no se puede deshacer. '
              'Para confirmar, escribe tu email exacto.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('delete-account-email-field'),
              controller: _emailController,
              enabled: !_isSubmitting,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email de confirmacion',
                hintText: widget.email,
                prefixIcon: const Icon(Icons.alternate_email_rounded),
              ),
              validator: (value) {
                if ((value ?? '').trim() != widget.email) {
                  return 'Escribe tu email exacto para confirmar.';
                }
                return null;
              },
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('confirm-delete-account-button'),
          onPressed: _emailMatches && !_isSubmitting ? _submit : null,
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.danger,
            foregroundColor: AppTheme.background,
          ),
          child: _isSubmitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.background,
                  ),
                )
              : const Text('Eliminar definitivamente'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      await widget.onConfirm();
    } catch (_) {
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: hasAvatar
                    ? null
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppTheme.surfaceElevated, AppTheme.input],
                      ),
                color: hasAvatar ? AppTheme.surfaceElevated : null,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: hasAvatar
                      ? AppTheme.borderStrong.withValues(alpha: 0.28)
                      : AppTheme.borderStrong.withValues(alpha: 0.24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.20),
                    blurRadius: 22,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: SizedBox(
                width: 104,
                height: 104,
                child: Center(
                  child: hasAvatar
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(31),
                          child: hasPreview
                              ? Image.memory(
                                  previewBytes!,
                                  width: 104,
                                  height: 104,
                                  fit: BoxFit.cover,
                                )
                              : Image.network(
                                  profile!.photoUrl!,
                                  width: 104,
                                  height: 104,
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
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                border: Border.all(
                  color: AppTheme.emerald.withValues(alpha: 0.20),
                ),
              ),
              child: const SizedBox.square(
                dimension: 30,
                child: Icon(
                  Icons.photo_camera_outlined,
                  color: AppTheme.emerald,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        FocusSectionHeader(title: 'Avatar'),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final changeButton = OutlinedButton.icon(
              onPressed: onPickAvatar,
              icon: const Icon(Icons.photo_camera_outlined, size: 18),
              label: const Text('Cambiar foto'),
              style: OutlinedButton.styleFrom(
                backgroundColor: AppTheme.input.withValues(alpha: 0.58),
                foregroundColor: AppTheme.textPrimary,
                side: BorderSide(
                  color: AppTheme.borderStrong.withValues(alpha: 0.28),
                ),
              ),
            );
            final removeButton = OutlinedButton.icon(
              onPressed: hasAvatar ? onRemoveAvatar : null,
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Eliminar foto'),
              style: OutlinedButton.styleFrom(
                backgroundColor: AppTheme.input.withValues(alpha: 0.46),
                foregroundColor: AppTheme.textPrimary,
                side: BorderSide(
                  color: AppTheme.borderStrong.withValues(alpha: 0.24),
                ),
              ),
            );
            if (constraints.maxWidth < 300) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: changeButton,
                  ),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: removeButton,
                  ),
                ],
              );
            }
            return Row(
              children: [
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: changeButton,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: removeButton,
                  ),
                ),
              ],
            );
          },
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
        color: AppTheme.input.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(AppTheme.radiusInput),
        border: Border.all(
          color: AppTheme.borderStrong.withValues(alpha: 0.22),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const SizedBox.square(
                dimension: 38,
                child: Icon(
                  Icons.alternate_email_rounded,
                  color: AppTheme.emerald,
                  size: 19,
                ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PushNotificationsSwitch extends StatelessWidget {
  const _PushNotificationsSwitch({
    required this.enabled,
    required this.isUpdating,
    required this.onChanged,
  });

  final bool enabled;
  final bool isUpdating;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.input.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(AppTheme.radiusInput),
        border: Border.all(
          color: enabled
              ? AppTheme.emerald.withValues(alpha: 0.16)
              : AppTheme.borderStrong.withValues(alpha: 0.22),
        ),
      ),
      child: SwitchListTile(
        value: enabled,
        onChanged: onChanged,
        activeThumbColor: AppTheme.emerald,
        activeTrackColor: AppTheme.emerald.withValues(alpha: 0.16),
        inactiveThumbColor: AppTheme.textSecondary,
        inactiveTrackColor: AppTheme.surfaceElevated,
        contentPadding: const EdgeInsets.fromLTRB(14, 4, 10, 4),
        secondary: DecoratedBox(
          decoration: BoxDecoration(
            color: AppTheme.surfaceElevated.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(14),
          ),
          child: SizedBox.square(
            dimension: 38,
            child: Center(
              child: isUpdating
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(
                      Icons.notifications_active_outlined,
                      color: AppTheme.emerald,
                      size: 20,
                    ),
            ),
          ),
        ),
        title: Text(
          'Notificaciones',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
