import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class FocusGlassCard extends StatelessWidget {
  const FocusGlassCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusHero),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class FocusBlackCard extends StatelessWidget {
  const FocusBlackCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(22),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.black,
        borderRadius: BorderRadius.circular(AppTheme.radiusHero),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: AppTheme.onBlack),
        child: IconTheme.merge(
          data: const IconThemeData(color: AppTheme.onBlack),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class FocusLimeCard extends StatelessWidget {
  const FocusLimeCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(22),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.lime,
        borderRadius: BorderRadius.circular(AppTheme.radiusHero),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: AppTheme.onLime),
        child: IconTheme.merge(
          data: const IconThemeData(color: AppTheme.onLime),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusHero),
        child: content,
      ),
    );
  }
}

class FocusPageScaffold extends StatelessWidget {
  const FocusPageScaffold({
    required this.child,
    super.key,
    this.bottomInset = true,
  });

  final Widget child;
  final bool bottomInset;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.background,
      child: SafeArea(
        bottom: false,
        child: child,
      ),
    );
  }
}
