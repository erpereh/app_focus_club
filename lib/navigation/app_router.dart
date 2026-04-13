import 'package:flutter/material.dart';

import '../features/auth/presentation/auth_screen.dart';
import '../features/auth/presentation/complete_google_profile_screen.dart';
import '../features/auth/presentation/reset_password_screen.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/home/presentation/home_placeholder_screen.dart';

class AppRouter {
  const AppRouter._();

  static const splash = '/';
  static const auth = '/auth';
  static const resetPassword = '/auth/reset-password';
  static const completeGoogleProfile = '/auth/complete-google-profile';
  static const dashboard = '/dashboard';

  static Route<void> onGenerateRoute(RouteSettings settings) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => switch (settings.name) {
        splash || null => const SplashScreen(),
        auth => const AuthScreen(),
        resetPassword => const ResetPasswordScreen(),
        completeGoogleProfile => const CompleteGoogleProfileScreen(),
        dashboard => const HomePlaceholderScreen(),
        _ => const HomePlaceholderScreen(),
      },
    );
  }
}
