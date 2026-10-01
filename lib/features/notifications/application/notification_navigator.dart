import 'package:flutter/foundation.dart';

import '../domain/notification_models.dart';

typedef NotificationTargetHandler =
    Future<void> Function(NotificationTarget target);

/// Keeps the destination of a tapped notification until an authenticated
/// client shell can open it.
///
/// Push taps (cold start or background) and history taps call [handle]. When
/// no shell is attached yet (splash, login, Google profile completion) the
/// target stays pending and is consumed as soon as [attach] is called.
class NotificationNavigator {
  NotificationNavigator();

  static final instance = NotificationNavigator();

  NotificationTarget? _pending;
  NotificationTargetHandler? _handler;

  /// Support conversation currently on screen, used to skip redundant
  /// foreground banners.
  final activeConversationId = ValueNotifier<String?>(null);

  NotificationTarget? get pending => _pending;
  bool get isAttached => _handler != null;

  void handle(NotificationTarget target) {
    _pending = target;
    _dispatch();
  }

  void attach(NotificationTargetHandler handler) {
    _handler = handler;
    _dispatch();
  }

  void detach(NotificationTargetHandler handler) {
    // Method tear-offs are equal but not always identical.
    if (_handler == handler) _handler = null;
  }

  /// Drops any pending destination, e.g. on logout.
  void clear() {
    _pending = null;
    activeConversationId.value = null;
  }

  void _dispatch() {
    final handler = _handler;
    final target = _pending;
    if (handler == null || target == null) return;
    _pending = null;
    handler(target);
  }
}
