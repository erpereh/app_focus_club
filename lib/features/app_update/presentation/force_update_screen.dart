import 'package:flutter/material.dart';

import '../../../shared/widgets/focus_auth_scaffold.dart';
import '../../../shared/widgets/focus_buttons.dart';
import '../../../shared/widgets/focus_glass_card.dart';
import '../../../shared/widgets/focus_status_message.dart';
import '../../../theme/app_theme.dart';

const _focusClubLogoAsset = 'assets/images/focus_club_logo.jpeg';

class ForceUpdateScreen extends StatefulWidget {
  const ForceUpdateScreen({
    required this.storeUrl,
    required this.onOpenStore,
    super.key,
  });

  final Uri storeUrl;
  final Future<bool> Function(Uri url) onOpenStore;

  @override
  State<ForceUpdateScreen> createState() => _ForceUpdateScreenState();
}

class _ForceUpdateScreenState extends State<ForceUpdateScreen> {
  bool _isOpening = false;
  String? _errorMessage;

  Future<void> _openStore() async {
    setState(() {
      _isOpening = true;
      _errorMessage = null;
    });
    try {
      final opened = await widget.onOpenStore(widget.storeUrl);
      if (!mounted) return;
      if (!opened) {
        setState(() {
          _errorMessage =
              'No hemos podido abrir la tienda. Intentalo de nuevo.';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'No hemos podido abrir la tienda. Intentalo de nuevo.';
      });
    } finally {
      if (mounted) {
        setState(() => _isOpening = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return PopScope(
      canPop: false,
      child: FocusAuthScaffold(
        child: FocusGlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: AppTheme.emerald.withValues(alpha: 0.24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.emerald.withValues(alpha: 0.12),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(7),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: SizedBox(
                        width: 82,
                        height: 82,
                        child: Image.asset(
                          _focusClubLogoAsset,
                          fit: BoxFit.cover,
                          semanticLabel: 'Focus Club',
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Actualizacion necesaria',
                textAlign: TextAlign.center,
                style: textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              Text(
                'Hemos publicado una nueva version de Focus Club '
                'necesaria para seguir utilizando la aplicacion.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium,
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 18),
                FocusStatusMessage(
                  message: _errorMessage!,
                  type: FocusStatusType.error,
                ),
              ],
              const SizedBox(height: 26),
              FocusPrimaryButton(
                label: 'Actualizar ahora',
                isLoading: _isOpening,
                onPressed: _isOpening ? null : _openStore,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
