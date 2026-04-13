import 'package:flutter/material.dart';

import '../navigation/app_router.dart';
import '../theme/app_theme.dart';

class FocusClubApp extends StatelessWidget {
  const FocusClubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Focus Club',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      initialRoute: AppRouter.home,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
