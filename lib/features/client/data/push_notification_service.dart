import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'portal_repository.dart';

class PushNotificationPermissionDenied implements Exception {
  const PushNotificationPermissionDenied();
}

class PushNotificationTokenUnavailable implements Exception {
  const PushNotificationTokenUnavailable();
}

abstract interface class PushMessagingClient {
  Stream<String> get onTokenRefresh;

  Future<NotificationSettings> requestPermission({
    required bool alert,
    required bool badge,
    required bool sound,
  });

  Future<String?> getAPNSToken();
  Future<String?> getToken();
}

class FirebasePushNotificationService {
  FirebasePushNotificationService({
    PushMessagingClient? messaging,
    TargetPlatform? targetPlatform,
    Future<void> Function(Duration duration)? delay,
    void Function(String message)? debugLog,
  }) : _messaging = messaging ?? _FirebasePushMessagingClient(),
       _targetPlatform = targetPlatform,
       _delay = delay ?? Future<void>.delayed,
       _debugLog = debugLog ?? debugPrint;

  static final instance = FirebasePushNotificationService();

  final PushMessagingClient _messaging;
  final TargetPlatform? _targetPlatform;
  final Future<void> Function(Duration duration) _delay;
  final void Function(String message) _debugLog;
  StreamSubscription<String>? _tokenRefreshSubscription;
  PortalRepository? _repository;
  String? _uid;
  bool _enabled = false;

  Future<void> configureForUser({
    required String uid,
    required bool enabled,
    required PortalRepository repository,
  }) async {
    _uid = uid;
    _enabled = enabled;
    _repository = repository;
    if (!enabled) return;
    _ensureTokenRefreshListener();
    await registerCurrentToken();
  }

  Future<void> enableForUser({
    required String uid,
    required PortalRepository repository,
  }) async {
    final platform = _effectivePlatform;
    try {
      _logPush('enable start platform=${_platformLabel(platform)}');
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      _logPush('authorizationStatus=${settings.authorizationStatus.name}');
      final isAllowed =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (!isAllowed) {
        throw const PushNotificationPermissionDenied();
      }

      final token = await _currentTokenOrThrow(platform);
      await repository.saveFcmToken(
        uid: uid,
        token: token,
        platform: _platformLabel(platform),
      );
      await repository.setPushNotificationsEnabled(uid: uid, enabled: true);
      _uid = uid;
      _enabled = true;
      _repository = repository;
      _ensureTokenRefreshListener();
    } catch (error, stackTrace) {
      _logPush('enable error=$error');
      _logPush('enable stackTrace=$stackTrace');
      rethrow;
    }
  }

  Future<void> disableForUser({
    required String uid,
    required PortalRepository repository,
  }) async {
    _uid = uid;
    _enabled = false;
    _repository = repository;
    await repository.setPushNotificationsEnabled(uid: uid, enabled: false);
  }

  Future<void> registerCurrentToken() async {
    final uid = _uid;
    final repository = _repository;
    if (!_enabled || uid == null || repository == null) return;
    final platform = _effectivePlatform;
    final token = await _currentTokenOrNull(platform);
    if (token == null) return;
    await repository.saveFcmToken(
      uid: uid,
      token: token,
      platform: _platformLabel(platform),
    );
  }

  Future<void> stop() async {
    _uid = null;
    _enabled = false;
    _repository = null;
    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
  }

  void _ensureTokenRefreshListener() {
    _tokenRefreshSubscription ??= _messaging.onTokenRefresh.listen((
      token,
    ) async {
      final uid = _uid;
      final repository = _repository;
      if (!_enabled || uid == null || repository == null) return;
      await repository.saveFcmToken(
        uid: uid,
        token: token,
        platform: _platformLabel(_effectivePlatform),
      );
    });
  }

  Future<String> _currentTokenOrThrow(TargetPlatform platform) async {
    final token = await _currentTokenOrNull(platform);
    if (token == null) {
      throw const PushNotificationTokenUnavailable();
    }
    return token;
  }

  Future<String?> _currentTokenOrNull(TargetPlatform platform) async {
    if (platform == TargetPlatform.iOS) {
      final apnsToken = await _waitForApnsToken();
      if (apnsToken == null) {
        _logPush('apnsToken=null');
        return null;
      }
      _logPush('apnsToken=not-null');
    }

    final token = await _messaging.getToken();
    final hasToken = token != null && token.trim().isNotEmpty;
    _logPush('fcmToken=${hasToken ? 'not-null' : 'null'}');
    return hasToken ? token : null;
  }

  Future<String?> _waitForApnsToken() async {
    for (var attempt = 0; attempt < 10; attempt += 1) {
      final token = await _getApnsToken();
      if (token != null && token.trim().isNotEmpty) {
        return token;
      }
      if (attempt < 9) {
        await _delay(const Duration(milliseconds: 500));
      }
    }
    return null;
  }

  Future<String?> _getApnsToken() {
    return _messaging.getAPNSToken();
  }

  TargetPlatform get _effectivePlatform =>
      _targetPlatform ?? defaultTargetPlatform;

  String _platformLabel(TargetPlatform platform) {
    return switch (platform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'unknown',
    };
  }

  void _logPush(String message) {
    _debugLog('[PushNotifications] $message');
  }
}

class _FirebasePushMessagingClient implements PushMessagingClient {
  @override
  Stream<String> get onTokenRefresh =>
      FirebaseMessaging.instance.onTokenRefresh;

  @override
  Future<String?> getAPNSToken() {
    return FirebaseMessaging.instance.getAPNSToken();
  }

  @override
  Future<String?> getToken() {
    return FirebaseMessaging.instance.getToken();
  }

  @override
  Future<NotificationSettings> requestPermission({
    required bool alert,
    required bool badge,
    required bool sound,
  }) {
    return FirebaseMessaging.instance.requestPermission(
      alert: alert,
      badge: badge,
      sound: sound,
    );
  }
}
