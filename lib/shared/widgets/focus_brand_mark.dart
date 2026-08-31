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
        color: AppTheme.lime,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Icon(icon, color: AppTheme.onLime, size: 30),
    );
  }
}
