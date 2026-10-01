import 'package:app_focus_club/features/notifications/application/notifications_view_model.dart';
import 'package:app_focus_club/features/notifications/data/notifications_repository.dart';
import 'package:app_focus_club/features/notifications/domain/notification_models.dart';
import 'package:app_focus_club/features/notifications/presentation/notifications_screen.dart';
import 'package:app_focus_club/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/notification_fixtures.dart';

void main() {
  group('NotificationsViewModel', () {
    test('syncs history and unread counter', () async {
      final repository = FakeNotificationsRepository(
        notifications: [
          testNotification(id: 'a', createdAt: DateTime(2026, 9, 29)),
          testNotification(
            id: 'b',
            read: true,
            createdAt: DateTime(2026, 9, 30),
          ),
        ],
      );
      final viewModel = NotificationsViewModel(
        repository: repository,
        uid: 'user-1',
      )..start();
      await pumpEventQueue();

      expect(viewModel.state.isLoading, isFalse);
      expect(viewModel.state.notifications.map((item) => item.id), ['b', 'a']);
      expect(viewModel.state.unreadCount, 1);

      repository.add(
        testNotification(id: 'c', createdAt: DateTime(2026, 10, 1)),
      );
      await pumpEventQueue();

      expect(viewModel.state.notifications.first.id, 'c');
      expect(viewModel.state.unreadCount, 2);
      viewModel.dispose();
    });

    test('markRead marks a single entry once', () async {
      final repository = FakeNotificationsRepository(
        notifications: [
          testNotification(id: 'a'),
          testNotification(id: 'b'),
        ],
      );
      final viewModel = NotificationsViewModel(
        repository: repository,
        uid: 'user-1',
      )..start();
      await pumpEventQueue();

      await viewModel.markRead('a');
      await viewModel.markRead('a');
      await pumpEventQueue();

      expect(repository.markedRead, ['a']);
      expect(viewModel.state.unreadCount, 1);
      expect(
        viewModel.state.notifications.firstWhere((item) => item.id == 'a').read,
        isTrue,
      );
      viewModel.dispose();
    });

    test('markAllRead clears the counter', () async {
      final repository = FakeNotificationsRepository(
        notifications: [
          testNotification(id: 'a'),
          testNotification(id: 'b'),
        ],
      );
      final viewModel = NotificationsViewModel(
        repository: repository,
        uid: 'user-1',
      )..start();
      await pumpEventQueue();

      await viewModel.markAllRead();
      await pumpEventQueue();

      expect(repository.markAllCalls, 1);
      expect(viewModel.state.unreadCount, 0);
      expect(viewModel.state.notifications.every((item) => item.read), isTrue);

      await viewModel.markAllRead();
      expect(repository.markAllCalls, 1);
      viewModel.dispose();
    });

    test('exposes load errors', () async {
      final viewModel = NotificationsViewModel(
        repository: FakeNotificationsRepository(failure: StateError('denied')),
        uid: 'user-1',
      )..start();
      await pumpEventQueue();

      expect(viewModel.state.isLoading, isFalse);
      expect(viewModel.state.error, isNotNull);
      expect(viewModel.state.unreadCount, 0);
      viewModel.dispose();
    });
  });

  group('NotificationsScreen', () {
    Future<
      ({
        FakeNotificationsRepository repository,
        List<NotificationTarget> opened,
      })
    >
    pumpScreen(WidgetTester tester, List<AppNotification> notifications) async {
      final repository = FakeNotificationsRepository(
        notifications: notifications,
      );
      final viewModel = NotificationsViewModel(
        repository: repository,
        uid: 'user-1',
      )..start();
      addTearDown(viewModel.dispose);
      final opened = <NotificationTarget>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: NotificationsScreen(
            viewModel: viewModel,
            onOpenTarget: opened.add,
            now: () => DateTime(2026, 9, 30, 12),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (repository: repository, opened: opened);
    }

    testWidgets('shows title, body, date and icon per event', (tester) async {
      await pumpScreen(tester, [
        testNotification(id: 'a', createdAt: DateTime(2026, 9, 30, 11, 55)),
        testNotification(
          id: 'b',
          type: 'bono_status',
          event: 'bono_expiring_2d',
          title: 'Tu bono caduca pronto',
          body: 'Quedan 2 días para que caduque tu bono.',
          createdAt: DateTime(2026, 9, 29, 18, 30),
          route: NotificationRoute.bono,
          params: const {'bonoId': 'b1'},
          read: true,
        ),
        testNotification(
          id: 'c',
          type: 'support_message',
          event: 'support_message',
          title: 'Nuevo mensaje de Focus Club',
          body: 'Tienes una nueva respuesta en el chat.',
          createdAt: DateTime(2026, 9, 12, 8, 5),
          route: NotificationRoute.chat,
          params: const {'conversationId': 'conv-1'},
        ),
      ]);

      expect(find.text('Notificaciones'), findsOneWidget);
      expect(find.text('2 sin leer'), findsOneWidget);
      expect(find.text('Cita confirmada'), findsOneWidget);
      expect(
        find.text('Tu cita del 15/01 a las 10:00 está confirmada.'),
        findsOneWidget,
      );
      expect(find.text('Hace 5 min'), findsOneWidget);
      expect(find.text('Tu bono caduca pronto'), findsOneWidget);
      expect(find.text('Ayer, 18:30'), findsOneWidget);
      expect(find.text('12/09/2026, 08:05'), findsOneWidget);

      Icon iconOf(String id) =>
          tester.widget<Icon>(find.byKey(Key('notification-icon-$id')));
      expect(iconOf('a').icon, Icons.check_circle_rounded);
      expect(iconOf('b').icon, Icons.hourglass_bottom_rounded);
      expect(iconOf('c').icon, Icons.chat_bubble_rounded);

      expect(find.byKey(const Key('notification-unread-a')), findsOneWidget);
      expect(find.byKey(const Key('notification-unread-b')), findsNothing);
      expect(find.byKey(const Key('notification-unread-c')), findsOneWidget);
    });

    testWidgets('tapping an entry marks it read and opens its target', (
      tester,
    ) async {
      final harness = await pumpScreen(tester, [testNotification(id: 'a')]);

      await tester.tap(find.byKey(const Key('notification-a')));
      await tester.pumpAndSettle();

      expect(harness.repository.markedRead, ['a']);
      expect(harness.opened, [
        const NotificationTarget(
          route: NotificationRoute.appointment,
          notificationId: 'a',
          appointmentId: 'apt-1',
        ),
      ]);
      expect(find.byKey(const Key('notification-unread-a')), findsNothing);
      expect(find.text('Todas leídas'), findsOneWidget);
    });

    testWidgets('mark all as read', (tester) async {
      final harness = await pumpScreen(tester, [
        testNotification(id: 'a'),
        testNotification(id: 'b'),
      ]);

      await tester.tap(find.byKey(const Key('notifications-mark-all')));
      await tester.pumpAndSettle();

      expect(harness.repository.markAllCalls, 1);
      expect(find.text('Todas leídas'), findsOneWidget);
      final button = tester.widget<IconButton>(
        find.byKey(const Key('notifications-mark-all')),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('empty state', (tester) async {
      await pumpScreen(tester, const []);

      expect(find.text('Sin notificaciones'), findsOneWidget);
      final button = tester.widget<IconButton>(
        find.byKey(const Key('notifications-mark-all')),
      );
      expect(button.onPressed, isNull);
    });
  });

  group('NotificationBellButton', () {
    Future<void> pumpBell(WidgetTester tester, int count) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotificationBellButton(unreadCount: count, onPressed: () {}),
          ),
        ),
      );
    }

    testWidgets('hides the badge without unread entries', (tester) async {
      await pumpBell(tester, 0);
      expect(
        find.byKey(const Key('dashboard-notifications-badge')),
        findsNothing,
      );
    });

    testWidgets('shows the unread count', (tester) async {
      await pumpBell(tester, 3);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('caps the counter at 99+', (tester) async {
      await pumpBell(tester, 150);
      expect(find.text('99+'), findsOneWidget);
    });
  });
}
