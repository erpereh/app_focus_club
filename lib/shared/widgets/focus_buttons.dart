import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class FocusPrimaryButton extends StatelessWidget {
  const FocusPrimaryButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null || isLoading;

    return Opacity(
      opacity: isDisabled ? 0.58 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusControl),
          color: AppTheme.emerald,
          boxShadow: [
            BoxShadow(
              color: AppTheme.emerald.withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(0, 9),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.transparent,
                disabledBackgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
              ),
              onPressed: isDisabled ? null : onPressed,
              child: isLoading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.background,
                      ),
                    )
                  : Text(label),
            ),
          ),
        ),
      ),
    );
  }
}

class FocusGhostButton extends StatelessWidget {
  const FocusGhostButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon ?? Icons.arrow_back_rounded, size: 18),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.textPrimary,
            backgroundColor: AppTheme.surfaceElevated.withValues(alpha: 0.52),
            side: BorderSide(
              color: AppTheme.borderStrong.withValues(alpha: 0.32),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusControl),
            ),
          ),
        ),
      ),
    );
  }
}

class FocusGoogleButton extends StatelessWidget {
  const FocusGoogleButton({
    required this.onPressed,
    super.key,
    this.isLoading = false,
  });

  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null || isLoading;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 50),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: isDisabled ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.textPrimary,
            backgroundColor: AppTheme.input.withValues(alpha: 0.58),
            side: BorderSide(
              color: AppTheme.borderStrong.withValues(alpha: 0.32),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusControl),
            ),
          ),
          child: isLoading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.textPrimary,
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _GoogleGlyph(),
                    SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        'Continuar con Google',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.textPrimary,
        borderRadius: BorderRadius.circular(AppTheme.radiusBadge),
      ),
      child: const SizedBox(
        width: 22,
        height: 22,
        child: Center(
          child: Text(
            'G',
            style: TextStyle(
              color: AppTheme.background,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}
