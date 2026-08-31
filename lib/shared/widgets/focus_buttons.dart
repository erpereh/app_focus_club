import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

enum FocusButtonTone { lime, black }

class FocusPrimaryButton extends StatelessWidget {
  const FocusPrimaryButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.isLoading = false,
    this.tone = FocusButtonTone.lime,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final FocusButtonTone tone;

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null || isLoading;
    final background = tone == FocusButtonTone.lime
        ? AppTheme.lime
        : AppTheme.black;
    final foreground = tone == FocusButtonTone.lime
        ? AppTheme.onLime
        : AppTheme.onBlack;

    return Opacity(
      opacity: isDisabled ? 0.5 : 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: background,
              foregroundColor: foreground,
              disabledBackgroundColor: background,
              disabledForegroundColor: foreground,
              shadowColor: Colors.transparent,
            ),
            onPressed: isDisabled ? null : onPressed,
            child: isLoading
                ? SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: foreground,
                    ),
                  )
                : Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
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
            backgroundColor: AppTheme.white,
            side: const BorderSide(color: AppTheme.borderStrong),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
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
            backgroundColor: AppTheme.white,
            side: const BorderSide(color: AppTheme.borderStrong),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
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
        color: AppTheme.black,
        borderRadius: BorderRadius.circular(AppTheme.radiusBadge),
      ),
      child: const SizedBox(
        width: 22,
        height: 22,
        child: Center(
          child: Text(
            'G',
            style: TextStyle(
              color: AppTheme.onBlack,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}
