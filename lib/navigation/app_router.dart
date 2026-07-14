import 'package:flutter/material.dart';

import '../features/auth/presentation/auth_screen.dart';
import '../features/auth/presentation/complete_google_profile_screen.dart';
import '../features/auth/presentation/reset_password_screen.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/client/presentation/client_shell_screen.dart';

class AppRouter {
  const AppRouter._();

  static final navigatorKey = GlobalKey<NavigatorState>();

  static const splash = '/';
  static const auth = '/auth';
  static const resetPassword = '/auth/reset-password';
  static const completeGoogleProfile = '/auth/complete-google-profile';
  static const dashboard = '/dashboard';

  static const dashboardTabAppointments = 1;
  static const dashboardTabChat = 2;

  static int? dashboardTabForNotificationType(String? type) => switch (type) {
    'appointment_status' => dashboardTabAppointments,
    'support_message' => dashboardTabChat,
    _ => null,
  };

  static Route<void> onGenerateRoute(RouteSettings settings) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => switch (settings.name) {
        splash || null => const SplashScreen(),
        auth => const AuthScreen(),
        resetPassword => const ResetPasswordScreen(),
        completeGoogleProfile => const CompleteGoogleProfileScreen(),
        dashboard => ClientShellScreen(
          initialTabIndex: _dashboardInitialTab(settings.arguments),
        ),
        _ => ClientShellScreen(
          initialTabIndex: _dashboardInitialTab(settings.arguments),
        ),
      },
    );
  }

  static int _dashboardInitialTab(Object? arguments) {
    return arguments == dashboardTabAppointments ||
            arguments == dashboardTabChat
        ? arguments as int
        : 0;
  }
}
