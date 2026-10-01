import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/notification_models.dart';

const notificationHistoryLimit = 100;

/// Reads and marks the customer history written by the web Cloud Functions
/// in `users/{uid}/notifications`. Rules only let the owner update `read`
/// and `readAt`; entries are never created or deleted from the app.
abstract interface class NotificationsRepository {
  Stream<List<AppNotification>> watchNotifications(
    String uid, {
    int limit = notificationHistoryLimit,
  });
  Stream<int> watchUnreadCount(String uid);
  Future<void> markAsRead({required String uid, required String id});
  Future<void> markAllAsRead(String uid);
}

class FirebaseNotificationsRepository implements NotificationsRepository {
  FirebaseNotificationsRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const _batchLimit = 450;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collection(String uid) =>
      _firestore.collection('users').doc(uid).collection('notifications');

  @override
  Stream<List<AppNotification>> watchNotifications(
    String uid, {
    int limit = notificationHistoryLimit,
  }) {
    return _collection(uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => AppNotification.fromMap(
                  doc.id,
                  Map<String, Object?>.from(doc.data()),
                ),
              )
              .toList(growable: false),
        );
  }

  @override
  Stream<int> watchUnreadCount(String uid) {
    return _collection(uid)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.size);
  }

  @override
  Future<void> markAsRead({required String uid, required String id}) {
    return _collection(
      uid,
    ).doc(id).update({'read': true, 'readAt': FieldValue.serverTimestamp()});
  }

  @override
  Future<void> markAllAsRead(String uid) async {
    final unread = await _collection(uid).where('read', isEqualTo: false).get();
    for (var index = 0; index < unread.docs.length; index += _batchLimit) {
      final batch = _firestore.batch();
      for (final doc in unread.docs.skip(index).take(_batchLimit)) {
        batch.update(doc.reference, {
          'read': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  }
}

class FakeNotificationsRepository implements NotificationsRepository {
  FakeNotificationsRepository({
    List<AppNotification> notifications = const [],
    this.failure,
  }) : _notifications = List<AppNotification>.from(notifications);

  List<AppNotification> _notifications;
  final Object? failure;
  final markedRead = <String>[];
  int markAllCalls = 0;
  final _changes = StreamController<void>.broadcast();

  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  /// Simulates a new history entry written by the backend.
  void add(AppNotification notification) {
    _notifications = [notification, ..._notifications];
    _changes.add(null);
  }

  @override
  Stream<List<AppNotification>> watchNotifications(
    String uid, {
    int limit = notificationHistoryLimit,
  }) async* {
    if (failure != null) throw failure!;
    yield _sorted().take(limit).toList(growable: false);
    await for (final _ in _changes.stream) {
      yield _sorted().take(limit).toList(growable: false);
    }
  }

  @override
  Stream<int> watchUnreadCount(String uid) async* {
    if (failure != null) throw failure!;
    yield _unreadCount;
    await for (final _ in _changes.stream) {
      yield _unreadCount;
    }
  }

  @override
  Future<void> markAsRead({required String uid, required String id}) async {
    if (failure != null) throw failure!;
    markedRead.add(id);
    _notifications = [
      for (final item in _notifications)
        item.id == id ? item.copyWith(read: true) : item,
    ];
    _changes.add(null);
  }

  @override
  Future<void> markAllAsRead(String uid) async {
    if (failure != null) throw failure!;
    markAllCalls += 1;
    _notifications = [
      for (final item in _notifications) item.copyWith(read: true),
    ];
    _changes.add(null);
  }

  int get _unreadCount => _notifications.where((item) => !item.read).length;

  List<AppNotification> _sorted() {
    final sorted = List<AppNotification>.from(_notifications);
    sorted.sort((a, b) {
      final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return sorted;
  }
}
