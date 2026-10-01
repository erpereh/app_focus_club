import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Small lime counter used for unread chat messages and notifications.
class FocusCountBadge extends StatelessWidget {
  const FocusCountBadge({required this.count, this.fontSize = 8, super.key});

  final int count;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppTheme.lime,
        shape: BoxShape.circle,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        child: Text(
          count > 99 ? '99+' : '$count',
          style: TextStyle(
            color: AppTheme.onLime,
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
