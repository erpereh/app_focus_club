import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class FocusBrandMark extends StatelessWidget {
  const FocusBrandMark({super.key, this.icon = Icons.bolt_rounded});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.emerald, AppTheme.emeraldDark],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.emerald.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Icon(icon, color: AppTheme.background, size: 30),
    );
  }
}
