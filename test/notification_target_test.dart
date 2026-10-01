import 'package:app_focus_club/features/notifications/domain/notification_models.dart';
import 'package:app_focus_club/features/notifications/domain/notification_presentation.dart';
import 'package:app_focus_club/features/notifications/presentation/foreground_notification_banner.dart';
import 'package:app_focus_club/navigation/app_router.dart';
import 'package:app_focus_club/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every `type`/`event` pair of web_focus_club/docs/notifications-contract.md.
const _contract = <String, List<String>>{
  'appointment_status': [
    'appointment_requested',
    'appointment_confirmed',
    'appointment_rescheduled',
    'appointment_rejected',
    'appointment_cancelled',
    'appointment_deleted',
    'appointment_reminder',
    'appointment_series_requested',
    'appointment_series_confirmed',
    'appointment_series_rejected',
    'appointment_series_cancelled',
    'appointment_series_rescheduled',
    'appointment_series_returned_to_pending',
  ],
  'bono_status': [
    'bono_assigned',
    'bono_renewed',
    'bono_exhausted',
    'bono_expired',
    'bono_validity_changed',
    'bono_expiring_7d',
    'bono_expiring_2d',
  ],
  'support_message': ['support_message'],
};

void main() {
  group('NotificationTarget.fromPushData', () {
    test('appointment payload opens the appointment', () {
      final target = NotificationTarget.fromPushData({
        'type': 'appointment_status',
        'event': 'appointment_confirmed',
        'notificationId': 'n1',
        'route': 'appointment',
        'appointmentId': 'apt123',
        'status': 'approved',
      });

      expect(
        target,
        const NotificationTarget(
          route: NotificationRoute.appointment,
          notificationId: 'n1',
          appointmentId: 'apt123',
        ),
      );
    });

    test('series payload goes to appointments and keeps the series', () {
      final data = {
        'type': 'appointment_status',
        'event': 'appointment_series_confirmed',
        'notificationId': 'n2',
        'route': 'appointments',
        'seriesId': 's1',
        'appointmentIds': 'a1, a2,,a3',
        'appointmentId': 'a1',
        'status': 'approved',
      };
      final target = NotificationTarget.fromPushData(data)!;

      expect(target.route, NotificationRoute.appointments);
      expect(target.seriesId, 's1');
      expect(target.appointmentId, 'a1');
      expect(parseAppointmentIds(data['appointmentIds']), ['a1', 'a2', 'a3']);
    });

    test('bono and chat payloads', () {
      expect(
        NotificationTarget.fromPushData({
          'type': 'bono_status',
          'event': 'bono_expiring_7d',
          'notificationId': 'n3',
          'route': 'bono',
          'bonoId': 'bono123',
        }),
        const NotificationTarget(
          route: NotificationRoute.bono,
          notificationId: 'n3',
          bonoId: 'bono123',
        ),
      );
      expect(
        NotificationTarget.fromPushData({
          'type': 'support_message',
          'event': 'support_message',
          'notificationId': 'n4',
          'route': 'chat',
          'conversationId': 'conv123',
        }),
        const NotificationTarget(
          route: NotificationRoute.chat,
          notificationId: 'n4',
          conversationId: 'conv123',
        ),
      );
    });

    test('legacy appointment_status without route still navigates', () {
      expect(
        NotificationTarget.fromPushData({
          'type': 'appointment_status',
          'appointmentId': 'apt-legacy',
        }),
        const NotificationTarget(
          route: NotificationRoute.appointment,
          appointmentId: 'apt-legacy',
        ),
      );
      expect(
        NotificationTarget.fromPushData({'type': 'appointment_status'}),
        const NotificationTarget(route: NotificationRoute.appointments),
      );
    });

    test('legacy support_message without route opens the chat', () {
      expect(
        NotificationTarget.fromPushData({
          'type': 'support_message',
          'conversationId': 'conv-legacy',
        }),
        const NotificationTarget(
          route: NotificationRoute.chat,
          conversationId: 'conv-legacy',
        ),
      );
      expect(
        NotificationTarget.fromPushData({'type': 'support_message'}),
        const NotificationTarget(route: NotificationRoute.chat),
      );
    });

    test('unknown types and empty payloads are ignored', () {
      expect(NotificationTarget.fromPushData({}), isNull);
      expect(NotificationTarget.fromPushData({'type': 'marketing'}), isNull);
      expect(
        NotificationTarget.fromPushData({'type': 'x', 'route': 'unknown'}),
        isNull,
      );
    });

    test('every contract event resolves a destination', () {
      for (final entry in _contract.entries) {
        for (final event in entry.value) {
          expect(
            NotificationTarget.fromPushData({
              'type': entry.key,
              'event': event,
            }),
            isNotNull,
            reason: '${entry.key}/$event',
          );
        }
      }
    });
  });

  group('AppNotification.fromMap', () {
    test('parses a history document', () {
      final notification = AppNotification.fromMap('n1', {
        'type': 'appointment_status',
        'event': 'appointment_series_rescheduled',
        'title': 'Serie modificada',
        'body': 'Hemos cambiado tus próximas sesiones.',
        'createdAt': DateTime(2026, 9, 30, 9, 15),
        'read': false,
        'appointmentId': 'a1',
        'bonoId': null,
        'conversationId': null,
        'seriesId': 's1',
        'status': 'approved',
        'appointmentIds': ['a1', 'a2'],
        'navigation': {
          'route': 'appointments',
          'params': {'seriesId': 's1'},
        },
      });

      expect(notification.category, NotificationCategory.appointmentStatus);
      expect(notification.read, isFalse);
      expect(notification.appointmentIds, ['a1', 'a2']);
      expect(
        notification.target,
        const NotificationTarget(
          route: NotificationRoute.appointments,
          notificationId: 'n1',
          appointmentId: 'a1',
          seriesId: 's1',
        ),
      );
    });

    test('tolerates legacy entries without event or navigation', () {
      final notification = AppNotification.fromMap('n2', {
        'type': 'support_message',
        'title': 'Nuevo mensaje de Focus Club',
        'conversationId': 'conv-1',
      });

      expect(notification.event, 'support_message');
      expect(notification.body, '');
      expect(notification.createdAt, isNull);
      expect(notification.read, isFalse);
      expect(notification.target?.route, NotificationRoute.chat);
      expect(notification.target?.conversationId, 'conv-1');
    });
  });

  group('presentation', () {
    test('every contract event has a specific icon and label', () {
      for (final entry in _contract.entries) {
        for (final event in entry.value) {
          final visual = notificationVisualFor(event: event, type: entry.key);
          expect(visual.icon, isNot(Icons.notifications_rounded));
          expect(visual.label, isNotEmpty);
        }
      }
    });

    test('icons follow the event semantics', () {
      expect(
        notificationVisualFor(
          event: 'appointment_confirmed',
          type: 'appointment_status',
        ).icon,
        Icons.check_circle_rounded,
      );
      expect(
        notificationVisualFor(
          event: 'appointment_rejected',
          type: 'appointment_status',
        ).color,
        AppTheme.danger,
      );
      expect(
        notificationVisualFor(
          event: 'appointment_reminder',
          type: 'appointment_status',
        ).icon,
        Icons.alarm_rounded,
      );
      expect(
        notificationVisualFor(
          event: 'bono_expiring_2d',
          type: 'bono_status',
        ).color,
        AppTheme.warning,
      );
      expect(
        notificationVisualFor(
          event: 'support_message',
          type: 'support_message',
        ).icon,
        Icons.chat_bubble_rounded,
      );
      expect(
        notificationVisualFor(event: 'future_event', type: 'bono_status').icon,
        Icons.confirmation_number_rounded,
      );
      expect(
        notificationVisualFor(event: 'x', type: 'x').icon,
        Icons.notifications_rounded,
      );
    });

    test('formats relative dates', () {
      final now = DateTime(2026, 9, 30, 12, 0);
      expect(formatNotificationDate(null, now), '');
      expect(formatNotificationDate(now, now), 'Ahora');
      expect(
        formatNotificationDate(now.subtract(const Duration(minutes: 5)), now),
        'Hace 5 min',
      );
      expect(
        formatNotificationDate(DateTime(2026, 9, 30, 9, 0), now),
        'Hace 3 h',
      );
      expect(
        formatNotificationDate(DateTime(2026, 9, 29, 18, 30), now),
        'Ayer, 18:30',
      );
      expect(
        formatNotificationDate(DateTime(2026, 9, 12, 8, 5), now),
        '12/09/2026, 08:05',
      );
    });
  });

  group('foreground notices', () {
    test('builds a notice from the FCM notification block', () {
      final notice = ForegroundNotificationController.noticeFor(
        data: {
          'type': 'bono_status',
          'event': 'bono_exhausted',
          'route': 'bono',
          'bonoId': 'b1',
        },
        title: 'Bono agotado',
        body: 'Ya no te quedan minutos.',
        activeConversationId: null,
      )!;

      expect(notice.title, 'Bono agotado');
      expect(notice.body, 'Ya no te quedan minutos.');
      expect(notice.target?.route, NotificationRoute.bono);
    });

    test('falls back to the event label without a title', () {
      final notice = ForegroundNotificationController.noticeFor(
        data: {
          'type': 'appointment_status',
          'event': 'appointment_reminder',
          'appointmentId': 'a1',
        },
        title: null,
        body: null,
        activeConversationId: null,
      )!;

      expect(notice.title, 'Recordatorio de cita');
    });

    test('skips chat messages for the conversation on screen', () {
      final data = {
        'type': 'support_message',
        'event': 'support_message',
        'route': 'chat',
        'conversationId': 'conv-1',
      };
      expect(
        ForegroundNotificationController.noticeFor(
          data: data,
          title: 'Nuevo mensaje de Focus Club',
          body: 'Tienes una nueva respuesta en el chat.',
          activeConversationId: 'conv-1',
        ),
        isNull,
      );
      expect(
        ForegroundNotificationController.noticeFor(
          data: data,
          title: 'Nuevo mensaje de Focus Club',
          body: 'Tienes una nueva respuesta en el chat.',
          activeConversationId: 'conv-2',
        ),
        isNotNull,
      );
    });
  });

  test('legacy tab mapping keeps working and supports bonos', () {
    expect(
      AppRouter.dashboardTabForNotificationType('appointment_status'),
      AppRouter.dashboardTabAppointments,
    );
    expect(
      AppRouter.dashboardTabForNotificationType('support_message'),
      AppRouter.dashboardTabChat,
    );
    expect(
      AppRouter.dashboardTabForNotificationType('bono_status'),
      AppRouter.dashboardTabHome,
    );
    expect(AppRouter.dashboardTabForNotificationType('other'), isNull);
  });
}
