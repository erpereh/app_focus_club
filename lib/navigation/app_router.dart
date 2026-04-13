import 'package:flutter/material.dart';

import '../features/home/presentation/home_placeholder_screen.dart';

class AppRouter {
  const AppRouter._();

  static const home = '/';

  static Route<void> onGenerateRoute(RouteSettings settings) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => switch (settings.name) {
        home || null => const HomePlaceholderScreen(),
        _ => const HomePlaceholderScreen(),
      },
    );
  }
}
