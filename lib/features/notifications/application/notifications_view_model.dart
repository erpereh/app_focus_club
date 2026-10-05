import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/notifications_repository.dart';
import '../domain/notification_models.dart';

class NotificationsState {
  const NotificationsState({
    this.notifications = const [],
    this.unreadCount = 0,
    this.isLoading = true,
    this.error,
    this.isMarkingAll = false,
    this.isClearing = false,
  });

  final List<AppNotification> notifications;
  final int unreadCount;
  final bool isLoading;
  final Object? error;
  final bool isMarkingAll;
  final bool isClearing;

  bool get hasUnread => unreadCount > 0;

  NotificationsState copyWith({
    List<AppNotification>? notifications,
    int? unreadCount,
    bool? isLoading,
    Object? error,
    bool clearError = false,
    bool? isMarkingAll,
    bool? isClearing,
  }) {
    return NotificationsState(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
      isMarkingAll: isMarkingAll ?? this.isMarkingAll,
      isClearing: isClearing ?? this.isClearing,
    );
  }
}

/// History synced with `users/{uid}/notifications` plus its unread counter.
class NotificationsViewModel extends ChangeNotifier {
  NotificationsViewModel({
    required NotificationsRepository repository,
    required String uid,
  }) : _repository = repository,
       _uid = uid;

  final NotificationsRepository _repository;
  final String _uid;
  StreamSubscription<List<AppNotification>>? _listSubscription;
  StreamSubscription<int>? _unreadSubscription;
  NotificationsState _state = const NotificationsState();
  bool _isDisposed = false;

  NotificationsState get state => _state;

  void start() {
    _listSubscription = _repository
        .watchNotifications(_uid)
        .listen(
          (notifications) => _emit(
            _state.copyWith(
              notifications: notifications,
              isLoading: false,
              clearError: true,
            ),
          ),
          onError: (Object error) =>
              _emit(_state.copyWith(isLoading: false, error: error)),
        );
    _unreadSubscription = _repository
        .watchUnreadCount(_uid)
        .listen(
          (count) => _emit(_state.copyWith(unreadCount: count)),
          onError: (Object _) => _emit(_state.copyWith(unreadCount: 0)),
        );
  }

  Future<void> markRead(String id) async {
    final index = _state.notifications.indexWhere((item) => item.id == id);
    if (index >= 0 && _state.notifications[index].read) return;
    if (index >= 0) {
      // Optimistic: the Firestore listener confirms it right after.
      final updated = List<AppNotification>.from(_state.notifications);
      updated[index] = updated[index].copyWith(read: true);
      _emit(
        _state.copyWith(
          notifications: updated,
          unreadCount: _state.unreadCount > 0 ? _state.unreadCount - 1 : 0,
        ),
      );
    }
    try {
      await _repository.markAsRead(uid: _uid, id: id);
    } catch (error) {
      debugPrint('[Notifications] markRead failed: $error');
    }
  }

  Future<void> markAllRead() async {
    if (!_state.hasUnread || _state.isMarkingAll) return;
    _emit(_state.copyWith(isMarkingAll: true));
    try {
      await _repository.markAllAsRead(_uid);
      _emit(
        _state.copyWith(
          notifications: [
            for (final item in _state.notifications) item.copyWith(read: true),
          ],
          unreadCount: 0,
          isMarkingAll: false,
        ),
      );
    } catch (error) {
      _emit(_state.copyWith(isMarkingAll: false, error: error));
    }
  }

  /// Removes one entry from `users/{uid}/notifications`. Optimistic; the
  /// previous list comes back if Firestore rejects it. Returns false then.
  Future<bool> deleteNotification(String id) async {
    final previous = _state;
    final index = previous.notifications.indexWhere((item) => item.id == id);
    if (index < 0) return true;
    final removed = previous.notifications[index];
    _emit(
      previous.copyWith(
        notifications: [
          for (final item in previous.notifications)
            if (item.id != id) item,
        ],
        unreadCount: !removed.read && previous.unreadCount > 0
            ? previous.unreadCount - 1
            : previous.unreadCount,
        clearError: true,
      ),
    );
    try {
      await _repository.deleteNotification(uid: _uid, id: id);
      return true;
    } catch (error) {
      debugPrint('[Notifications] delete failed: $error');
      _emit(previous.copyWith(error: error));
      return false;
    }
  }

  /// Deletes the whole history of the signed-in customer. Returns false if
  /// Firestore rejects it (the previous list comes back).
  Future<bool> clearAll() async {
    if (_state.notifications.isEmpty || _state.isClearing) return true;
    final previous = _state;
    _emit(
      previous.copyWith(
        notifications: const [],
        unreadCount: 0,
        isClearing: true,
        clearError: true,
      ),
    );
    try {
      await _repository.clearAll(_uid);
      _emit(_state.copyWith(isClearing: false));
      return true;
    } catch (error) {
      debugPrint('[Notifications] clear failed: $error');
      _emit(previous.copyWith(isClearing: false, error: error));
      return false;
    }
  }

  void _emit(NotificationsState state) {
    if (_isDisposed) return;
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _listSubscription?.cancel();
    _unreadSubscription?.cancel();
    super.dispose();
  }
}
