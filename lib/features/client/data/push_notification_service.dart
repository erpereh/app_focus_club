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

class FirebasePushNotificationService {
  FirebasePushNotificationService._({FirebaseMessaging? messaging})
    : _messaging = messaging;

  static final instance = FirebasePushNotificationService._();

  final FirebaseMessaging? _messaging;
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
    final settings = await _messagingInstance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    final isAllowed =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
    if (!isAllowed) {
      throw const PushNotificationPermissionDenied();
    }

    _uid = uid;
    _enabled = true;
    _repository = repository;
    _ensureTokenRefreshListener();
    final token = await _currentTokenOrThrow();
    await repository.saveFcmToken(
      uid: uid,
      token: token,
      platform: _platformLabel(),
    );
    await repository.setPushNotificationsEnabled(uid: uid, enabled: true);
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
    final token = await _messagingInstance.getToken();
    if (token == null || token.trim().isEmpty) return;
    await repository.saveFcmToken(
      uid: uid,
      token: token,
      platform: _platformLabel(),
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
    _tokenRefreshSubscription ??= _messagingInstance.onTokenRefresh.listen((
      token,
    ) async {
      final uid = _uid;
      final repository = _repository;
      if (!_enabled || uid == null || repository == null) return;
      await repository.saveFcmToken(
        uid: uid,
        token: token,
        platform: _platformLabel(),
      );
    });
  }

  Future<String> _currentTokenOrThrow() async {
    final token = await _messagingInstance.getToken();
    if (token == null || token.trim().isEmpty) {
      throw const PushNotificationTokenUnavailable();
    }
    return token;
  }

  String _platformLabel() {
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'unknown',
    };
  }

  FirebaseMessaging get _messagingInstance =>
      _messaging ?? FirebaseMessaging.instance;
}
