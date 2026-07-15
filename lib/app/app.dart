import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../features/auth/application/auth_scope.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/client/application/portal_scope.dart';
import '../features/client/data/portal_repository.dart';
import '../features/support/application/support_scope.dart';
import '../features/support/data/support_repository.dart';
import '../navigation/app_router.dart';
import '../theme/app_theme.dart';
import '../theme/app_text_size.dart';

class FocusClubApp extends StatefulWidget {
  FocusClubApp({
    super.key,
    AuthRepository? authRepository,
    PortalRepository? portalRepository,
    SupportRepository? supportRepository,
  }) : authRepository = authRepository ?? FirebaseAuthRepository(),
       portalRepository = portalRepository ?? FirebasePortalRepository(),
       supportRepository = supportRepository ?? FirebaseSupportRepository(),
       _enablePushNotificationNavigation =
           authRepository == null &&
           portalRepository == null &&
           supportRepository == null;

  final AuthRepository authRepository;
  final PortalRepository portalRepository;
  final SupportRepository supportRepository;
  final bool _enablePushNotificationNavigation;

  @override
  State<FocusClubApp> createState() => _FocusClubAppState();
}

class _FocusClubAppState extends State<FocusClubApp> {
  StreamSubscription<RemoteMessage>? _notificationOpenSubscription;
  AppTextSize _textSize = AppTextSize.defaultSize;

  @override
  void initState() {
    super.initState();
    if (!widget._enablePushNotificationNavigation) return;
    FirebaseMessaging.instance.getInitialMessage().then(_openNotification);
    _notificationOpenSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      _openNotification,
    );
  }

  @override
  void dispose() {
    _notificationOpenSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScope(
      repository: widget.authRepository,
      child: PortalScope(
        repository: widget.portalRepository,
        child: SupportScope(
          repository: widget.supportRepository,
          child: AppTextSizeScope(
            textSize: _textSize,
            onChanged: (value) {
              if (value != _textSize) setState(() => _textSize = value);
            },
            child: MaterialApp(
              navigatorKey: AppRouter.navigatorKey,
              title: 'Focus Club',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.dark,
              builder: (context, child) => AppTextSizing.applyGlobally(
                context,
                child: child ?? const SizedBox.shrink(),
              ),
              initialRoute: AppRouter.splash,
              onGenerateRoute: AppRouter.onGenerateRoute,
            ),
          ),
        ),
      ),
    );
  }

  void _openNotification(RemoteMessage? message) {
    final dashboardTab = AppRouter.dashboardTabForNotificationType(
      message?.data['type'],
    );
    if (dashboardTab == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppRouter.navigatorKey.currentState?.pushNamedAndRemoveUntil(
        AppRouter.dashboard,
        (route) => false,
        arguments: dashboardTab,
      );
    });
  }
}
