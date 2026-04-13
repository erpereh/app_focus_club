import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

enum FocusStatusType { success, warning, error }

class FocusStatusMessage extends StatelessWidget {
  const FocusStatusMessage({
    required this.message,
    required this.type,
    super.key,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final FocusStatusType type;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final color = switch (type) {
      FocusStatusType.success => AppTheme.emerald,
      FocusStatusType.warning => AppTheme.amber,
      FocusStatusType.error => AppTheme.danger,
    };
    final icon = switch (type) {
      FocusStatusType.success => Icons.check_circle_rounded,
      FocusStatusType.warning => Icons.mark_email_unread_rounded,
      FocusStatusType.error => Icons.error_rounded,
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(AppTheme.radiusInput),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 34),
                  foregroundColor: color,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
