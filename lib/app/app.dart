import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../features/app_update/data/installed_app_build_reader.dart';
import '../features/app_update/domain/app_update_decision.dart';
import '../features/app_update/presentation/version_gate.dart';
import '../features/auth/application/auth_scope.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/client/application/portal_scope.dart';
import '../features/client/data/portal_repository.dart';
import '../features/client/data/push_notification_service.dart';
import '../features/notifications/application/notification_navigator.dart';
import '../features/notifications/application/notifications_scope.dart';
import '../features/notifications/data/notifications_repository.dart';
import '../features/notifications/domain/notification_models.dart';
import '../features/notifications/presentation/foreground_notification_banner.dart';
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
    NotificationsRepository? notificationsRepository,
    this.installedAppBuildReader,
    this.appStorePlatform,
    this.storeUrlLauncher,
  }) : authRepository = authRepository ?? FirebaseAuthRepository(),
       portalRepository = portalRepository ?? FirebasePortalRepository(),
       supportRepository = supportRepository ?? FirebaseSupportRepository(),
       // Injected repositories mean a test harness without Firebase.
       notificationsRepository =
           notificationsRepository ??
           (authRepository == null &&
                   portalRepository == null &&
                   supportRepository == null
               ? FirebaseNotificationsRepository()
               : FakeNotificationsRepository()),
       _enablePushNotificationNavigation =
           authRepository == null &&
           portalRepository == null &&
           supportRepository == null;

  final AuthRepository authRepository;
  final PortalRepository portalRepository;
  final SupportRepository supportRepository;
  final NotificationsRepository notificationsRepository;
  final InstalledAppBuildReader? installedAppBuildReader;
  final AppStorePlatform? appStorePlatform;
  final Future<bool> Function(Uri)? storeUrlLauncher;
  final bool _enablePushNotificationNavigation;

  @override
  State<FocusClubApp> createState() => _FocusClubAppState();
}

class _FocusClubAppState extends State<FocusClubApp> {
  StreamSubscription<RemoteMessage>? _notificationOpenSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  final _foregroundController = ForegroundNotificationController();
  AppTextSize _textSize = AppTextSize.defaultSize;

  NotificationNavigator get _navigator => NotificationNavigator.instance;

  @override
  void initState() {
    super.initState();
    if (!widget._enablePushNotificationNavigation) return;
    // Taps are queued in NotificationNavigator and opened by the client
    // shell once the splash auth gate (or login) has finished.
    FirebaseMessaging.instance.getInitialMessage().then(_openNotification);
    _notificationOpenSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      _openNotification,
    );
    _foregroundSubscription = FirebasePushNotificationService
        .instance
        .foregroundMessages
        .listen(_showForegroundNotification);
  }

  @override
  void dispose() {
    _notificationOpenSubscription?.cancel();
    _foregroundSubscription?.cancel();
    _foregroundController.dispose();
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
          child: NotificationsScope(
            repository: widget.notificationsRepository,
            child: AppTextSizeScope(
              textSize: _textSize,
              onChanged: (value) {
                if (value != _textSize) setState(() => _textSize = value);
              },
              child: MaterialApp(
                navigatorKey: AppRouter.navigatorKey,
                title: 'Focus Club',
                debugShowCheckedModeBanner: false,
                theme: AppTheme.light,
                builder: (context, child) => VersionGate(
                  buildReader: widget.installedAppBuildReader,
                  platform: widget.appStorePlatform,
                  urlLauncher: widget.storeUrlLauncher,
                  child: ForegroundNotificationHost(
                    controller: _foregroundController,
                    onOpen: _navigator.handle,
                    child: AppTextSizing.applyGlobally(
                      context,
                      child: child ?? const SizedBox.shrink(),
                    ),
                  ),
                ),
                initialRoute: AppRouter.splash,
                onGenerateRoute: AppRouter.onGenerateRoute,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openNotification(RemoteMessage? message) {
    if (message == null) return;
    final target = NotificationTarget.fromPushData(message.data);
    if (target == null) return;
    _navigator.handle(target);
  }

  void _showForegroundNotification(RemoteMessage message) {
    final notice = ForegroundNotificationController.noticeFor(
      data: message.data,
      title: message.notification?.title,
      body: message.notification?.body,
      activeConversationId: _navigator.activeConversationId.value,
    );
    if (notice == null) {
      // Already reading that conversation: the history entry is redundant.
      final notificationId = message.data['notificationId'];
      if (notificationId is String && notificationId.isNotEmpty) {
        _markHistoryRead(notificationId);
      }
      return;
    }
    _foregroundController.show(notice);
  }

  void _markHistoryRead(String notificationId) {
    final uid = widget.authRepository.currentSession?.uid;
    if (uid == null) return;
    unawaited(
      widget.notificationsRepository
          .markAsRead(uid: uid, id: notificationId)
          .catchError((Object error) {
            debugPrint('[Notifications] markRead failed: $error');
          }),
    );
  }
}
