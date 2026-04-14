import 'package:flutter/material.dart';

import '../features/auth/application/auth_scope.dart';
import '../features/auth/data/auth_repository.dart';
import '../navigation/app_router.dart';
import '../theme/app_theme.dart';

class FocusClubApp extends StatelessWidget {
  FocusClubApp({super.key, AuthRepository? authRepository})
    : authRepository = authRepository ?? FirebaseAuthRepository();

  final AuthRepository authRepository;

  @override
  Widget build(BuildContext context) {
    return AuthScope(
      repository: authRepository,
      child: MaterialApp(
        title: 'Focus Club',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        initialRoute: AppRouter.splash,
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );
  }
}
