import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class FocusSectionHeader extends StatelessWidget {
  const FocusSectionHeader({
    required this.title,
    super.key,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              foregroundColor: AppTheme.textSecondary,
            ),
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

class FocusKicker extends StatelessWidget {
  const FocusKicker(this.label, {super.key, this.onDark = false});

  final String label;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: onDark ? AppTheme.lime : AppTheme.textSecondary,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
    );
  }
}
