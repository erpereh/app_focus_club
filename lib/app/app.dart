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
          child: MaterialApp(
            navigatorKey: AppRouter.navigatorKey,
            title: 'Focus Club',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.dark,
            initialRoute: AppRouter.splash,
            onGenerateRoute: AppRouter.onGenerateRoute,
          ),
        ),
      ),
    );
  }

  void _openNotification(RemoteMessage? message) {
    if (message?.data['type'] != 'appointment_status') return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppRouter.navigatorKey.currentState?.pushNamedAndRemoveUntil(
        AppRouter.dashboard,
        (route) => false,
        arguments: AppRouter.dashboardTabAppointments,
      );
    });
  }
}
