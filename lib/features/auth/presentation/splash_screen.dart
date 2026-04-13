import 'dart:async';

import 'package:flutter/material.dart';

import '../../../navigation/app_router.dart';
import '../../../shared/widgets/focus_auth_scaffold.dart';
import '../../../shared/widgets/focus_brand_mark.dart';
import '../../../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(AppRouter.auth);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return FocusAuthScaffold(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const FocusBrandMark(),
          const SizedBox(height: 22),
          Text(
            'Focus Club',
            textAlign: TextAlign.center,
            style: textTheme.headlineLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Portal del Cliente',
            textAlign: TextAlign.center,
            style: textTheme.bodyLarge,
          ),
          const SizedBox(height: 28),
          const SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.emerald,
            ),
          ),
        ],
      ),
    );
  }
}
