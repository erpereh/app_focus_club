/// Customer notification contract shared with the web backend.
///
/// See `web_focus_club/docs/notifications-contract.md`. The FCM `data`
/// payload and the `users/{uid}/notifications` history use the same `type`
/// (stable category) and `event` (concrete change) values.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationTypes {
  const NotificationTypes._();

  static const appointmentStatus = 'appointment_status';
  static const bonoStatus = 'bono_status';
  static const supportMessage = 'support_message';
}

enum NotificationCategory {
  appointmentStatus,
  bonoStatus,
  supportMessage,
  unknown;

  static NotificationCategory fromType(String? type) => switch (type) {
    NotificationTypes.appointmentStatus => appointmentStatus,
    NotificationTypes.bonoStatus => bonoStatus,
    NotificationTypes.supportMessage => supportMessage,
    _ => unknown,
  };
}

enum NotificationRoute {
  appointment('appointment'),
  appointments('appointments'),
  bono('bono'),
  chat('chat');

  const NotificationRoute(this.value);

  final String value;

  static NotificationRoute? fromValue(String? value) {
    for (final route in values) {
      if (route.value == value) return route;
    }
    return null;
  }
}

/// Where a notification tap should take the customer.
class NotificationTarget {
  const NotificationTarget({
    required this.route,
    this.notificationId,
    this.appointmentId,
    this.seriesId,
    this.bonoId,
    this.conversationId,
  });

  final NotificationRoute route;
  final String? notificationId;
  final String? appointmentId;
  final String? seriesId;
  final String? bonoId;
  final String? conversationId;

  /// Parses an FCM `data` payload. Supports the current contract (`route`
  /// plus ids) and legacy payloads that only carry `type` and an id.
  static NotificationTarget? fromPushData(Map<String, dynamic> data) {
    final type = _string(data['type']);
    return _resolve(
      route: NotificationRoute.fromValue(_string(data['route'])),
      category: NotificationCategory.fromType(type),
      notificationId: _string(data['notificationId']),
      appointmentId: _string(data['appointmentId']),
      seriesId: _string(data['seriesId']),
      bonoId: _string(data['bonoId']),
      conversationId: _string(data['conversationId']),
    );
  }

  static NotificationTarget? fromHistory(AppNotification notification) {
    final params = notification.navigationParams;
    return _resolve(
      route: notification.navigationRoute,
      category: notification.category,
      notificationId: notification.id,
      appointmentId: params['appointmentId'] ?? notification.appointmentId,
      seriesId: params['seriesId'] ?? notification.seriesId,
      bonoId: params['bonoId'] ?? notification.bonoId,
      conversationId: params['conversationId'] ?? notification.conversationId,
    );
  }

  static NotificationTarget? _resolve({
    required NotificationRoute? route,
    required NotificationCategory category,
    required String? notificationId,
    required String? appointmentId,
    required String? seriesId,
    required String? bonoId,
    required String? conversationId,
  }) {
    final resolvedRoute =
        route ??
        switch (category) {
          NotificationCategory.appointmentStatus =>
            appointmentId == null
                ? NotificationRoute.appointments
                : NotificationRoute.appointment,
          NotificationCategory.bonoStatus => NotificationRoute.bono,
          NotificationCategory.supportMessage => NotificationRoute.chat,
          NotificationCategory.unknown => null,
        };
    if (resolvedRoute == null) return null;
    return NotificationTarget(
      route: resolvedRoute,
      notificationId: notificationId,
      appointmentId: appointmentId,
      seriesId: seriesId,
      bonoId: bonoId,
      conversationId: conversationId,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is NotificationTarget &&
      other.route == route &&
      other.notificationId == notificationId &&
      other.appointmentId == appointmentId &&
      other.seriesId == seriesId &&
      other.bonoId == bonoId &&
      other.conversationId == conversationId;

  @override
  int get hashCode => Object.hash(
    route,
    notificationId,
    appointmentId,
    seriesId,
    bonoId,
    conversationId,
  );

  @override
  String toString() =>
      'NotificationTarget(${route.value}, appointment: $appointmentId, '
      'series: $seriesId, bono: $bonoId, conversation: $conversationId)';
}

/// Entry of `users/{uid}/notifications/{notificationId}`.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.event,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.read,
    this.appointmentId,
    this.bonoId,
    this.conversationId,
    this.seriesId,
    this.status,
    this.appointmentIds = const [],
    this.navigationRoute,
    this.navigationParams = const {},
  });

  factory AppNotification.fromMap(String id, Map<String, Object?> data) {
    final type = _string(data['type']) ?? '';
    final navigation = data['navigation'];
    NotificationRoute? route;
    var params = const <String, String>{};
    if (navigation is Map) {
      route = NotificationRoute.fromValue(_string(navigation['route']));
      final rawParams = navigation['params'];
      if (rawParams is Map) {
        params = {
          for (final entry in rawParams.entries)
            if (_string(entry.value) != null)
              entry.key.toString(): _string(entry.value)!,
        };
      }
    }
    final rawIds = data['appointmentIds'];
    return AppNotification(
      id: id,
      type: type,
      // Older entries may lack `event`; the category is the best fallback.
      event: _string(data['event']) ?? type,
      title: _string(data['title']) ?? '',
      body: _string(data['body']) ?? '',
      createdAt: _dateTime(data['createdAt']),
      read: data['read'] == true,
      appointmentId: _string(data['appointmentId']),
      bonoId: _string(data['bonoId']),
      conversationId: _string(data['conversationId']),
      seriesId: _string(data['seriesId']),
      status: _string(data['status']),
      appointmentIds: rawIds is List
          ? rawIds.map(_string).whereType<String>().toList(growable: false)
          : const [],
      navigationRoute: route,
      navigationParams: params,
    );
  }

  final String id;
  final String type;
  final String event;
  final String title;
  final String body;
  final DateTime? createdAt;
  final bool read;
  final String? appointmentId;
  final String? bonoId;
  final String? conversationId;
  final String? seriesId;
  final String? status;
  final List<String> appointmentIds;
  final NotificationRoute? navigationRoute;
  final Map<String, String> navigationParams;

  NotificationCategory get category => NotificationCategory.fromType(type);

  NotificationTarget? get target => NotificationTarget.fromHistory(this);

  AppNotification copyWith({bool? read}) {
    return AppNotification(
      id: id,
      type: type,
      event: event,
      title: title,
      body: body,
      createdAt: createdAt,
      read: read ?? this.read,
      appointmentId: appointmentId,
      bonoId: bonoId,
      conversationId: conversationId,
      seriesId: seriesId,
      status: status,
      appointmentIds: appointmentIds,
      navigationRoute: navigationRoute,
      navigationParams: navigationParams,
    );
  }
}

/// Splits the comma separated `appointmentIds` value of an FCM payload.
List<String> parseAppointmentIds(Object? value) {
  final raw = _string(value);
  if (raw == null) return const [];
  return raw
      .split(',')
      .map((id) => id.trim())
      .where((id) => id.isNotEmpty)
      .toList(growable: false);
}

String? _string(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

DateTime? _dateTime(Object? value) {
  return switch (value) {
    Timestamp() => value.toDate(),
    DateTime() => value,
    int() => DateTime.fromMillisecondsSinceEpoch(value),
    _ => null,
  };
}
