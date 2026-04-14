import 'package:flutter/material.dart';

import '../application/auth_scope.dart';
import '../data/auth_repository.dart';
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
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _resolveSession();
  }

  Future<void> _resolveSession() async {
    final authRepository = AuthScope.of(context);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    try {
      final session = await authRepository.authStateChanges().first.timeout(
        const Duration(seconds: 5),
        onTimeout: () => authRepository.currentSession,
      );
      if (!mounted) return;
      if (session == null) {
        Navigator.of(context).pushReplacementNamed(AppRouter.auth);
        return;
      }

      final gate = await authRepository.resolveAuthGate();
      if (!mounted) return;
      final route = switch (gate) {
        AuthGateResult.signedOut => AppRouter.auth,
        AuthGateResult.needsGoogleProfile => AppRouter.completeGoogleProfile,
        AuthGateResult.signedIn => AppRouter.dashboard,
      };
      Navigator.of(context).pushReplacementNamed(route);
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(AppRouter.auth);
    }
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
