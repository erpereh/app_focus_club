import 'package:app_focus_club/features/notifications/application/notifications_view_model.dart';
import 'package:app_focus_club/features/notifications/data/notifications_repository.dart';
import 'package:app_focus_club/features/notifications/domain/notification_models.dart';
import 'package:app_focus_club/features/notifications/presentation/notifications_screen.dart';
import 'package:app_focus_club/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
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

    test('deleteNotification removes only that entry', () async {
      final repository = FakeNotificationsRepository(
        notifications: [
          testNotification(id: 'a'),
          testNotification(id: 'b', read: true),
        ],
      );
      final viewModel = NotificationsViewModel(
        repository: repository,
        uid: 'user-1',
      )..start();
      await pumpEventQueue();

      expect(await viewModel.deleteNotification('a'), isTrue);
      await pumpEventQueue();

      expect(repository.deletedIds, ['a']);
      expect(viewModel.state.notifications.map((item) => item.id), ['b']);
      expect(viewModel.state.unreadCount, 0);
      viewModel.dispose();
    });

    test('clearAll empties the history and the counter', () async {
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

      expect(await viewModel.clearAll(), isTrue);
      await pumpEventQueue();

      expect(repository.clearCalls, 1);
      expect(repository.notifications, isEmpty);
      expect(viewModel.state.notifications, isEmpty);
      expect(viewModel.state.unreadCount, 0);
      expect(viewModel.state.isClearing, isFalse);

      // Nothing left to clear: no second request.
      expect(await viewModel.clearAll(), isTrue);
      expect(repository.clearCalls, 1);
      viewModel.dispose();
    });

    test('restores the history when a deletion is rejected', () async {
      final repository = FakeNotificationsRepository(
        notifications: [
          testNotification(id: 'a'),
          testNotification(id: 'b'),
        ],
        deleteFailure: StateError('permission-denied'),
      );
      final viewModel = NotificationsViewModel(
        repository: repository,
        uid: 'user-1',
      )..start();
      await pumpEventQueue();

      expect(await viewModel.deleteNotification('a'), isFalse);
      expect(viewModel.state.notifications.map((item) => item.id), ['a', 'b']);
      expect(viewModel.state.unreadCount, 2);

      expect(await viewModel.clearAll(), isFalse);
      expect(viewModel.state.notifications, hasLength(2));
      expect(viewModel.state.unreadCount, 2);
      expect(viewModel.state.isClearing, isFalse);
      expect(repository.notifications, hasLength(2));
      viewModel.dispose();
    });

    test('deletions persist across a new session (app restart)', () async {
      final repository = FakeNotificationsRepository(
        notifications: [
          testNotification(id: 'a'),
          testNotification(id: 'b'),
          testNotification(id: 'c'),
        ],
      );
      final first = NotificationsViewModel(
        repository: repository,
        uid: 'user-1',
      )..start();
      await pumpEventQueue();
      await first.deleteNotification('b');
      first.dispose();

      final second = NotificationsViewModel(
        repository: repository,
        uid: 'user-1',
      )..start();
      await pumpEventQueue();
      expect(second.state.notifications.map((item) => item.id), ['a', 'c']);
      await second.clearAll();
      second.dispose();

      final third = NotificationsViewModel(
        repository: repository,
        uid: 'user-1',
      )..start();
      await pumpEventQueue();
      expect(third.state.notifications, isEmpty);
      expect(third.state.unreadCount, 0);
      third.dispose();
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
    pumpScreen(
      WidgetTester tester,
      List<AppNotification> notifications, {
      FakeNotificationsRepository? existing,
      Object? deleteFailure,
    }) async {
      final repository =
          existing ??
          FakeNotificationsRepository(
            notifications: notifications,
            deleteFailure: deleteFailure,
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

    Future<void> swipeLeft(WidgetTester tester, String id) async {
      await tester.drag(
        find.byKey(Key('notification-$id')),
        const Offset(-200, 0),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('swiping left reveals a red delete button', (tester) async {
      await pumpScreen(tester, [testNotification(id: 'a')]);

      expect(find.byKey(const Key('notification-delete-a')), findsNothing);
      await swipeLeft(tester, 'a');

      final deleteButton = find.byKey(const Key('notification-delete-a'));
      expect(deleteButton, findsOneWidget);
      expect(find.text('Eliminar'), findsOneWidget);
      final material = tester.widget<Material>(
        find.ancestor(of: deleteButton, matching: find.byType(Material)).first,
      );
      expect(material.color, AppTheme.danger);
      expect(tester.getSize(deleteButton).height, greaterThanOrEqualTo(48));
      // The revealed button is really tappable (not covered by the card).
      expect(deleteButton.hitTestable(), findsOneWidget);
    });

    testWidgets('swiping back or tapping the card cancels the deletion', (
      tester,
    ) async {
      final harness = await pumpScreen(tester, [testNotification(id: 'a')]);

      await swipeLeft(tester, 'a');
      await tester.drag(
        find.byKey(const Key('notification-swipe-close-a')),
        const Offset(200, 0),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('notification-delete-a')), findsNothing);

      await swipeLeft(tester, 'a');
      await tester.tap(find.byKey(const Key('notification-swipe-close-a')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('notification-delete-a')), findsNothing);

      expect(harness.repository.deletedIds, isEmpty);
      expect(harness.repository.markedRead, isEmpty);
      expect(harness.opened, isEmpty);
      expect(find.byKey(const Key('notification-a')), findsOneWidget);
    });

    testWidgets('only one card stays open at a time', (tester) async {
      await pumpScreen(tester, [
        testNotification(id: 'a', createdAt: DateTime(2026, 9, 30, 11)),
        testNotification(id: 'b', createdAt: DateTime(2026, 9, 30, 10)),
      ]);

      await swipeLeft(tester, 'a');
      await swipeLeft(tester, 'b');

      expect(find.byKey(const Key('notification-delete-a')), findsNothing);
      expect(find.byKey(const Key('notification-delete-b')), findsOneWidget);
    });

    testWidgets('deleting one removes only that notification', (tester) async {
      final harness = await pumpScreen(tester, [
        testNotification(id: 'a', createdAt: DateTime(2026, 9, 30, 11)),
        testNotification(id: 'b', createdAt: DateTime(2026, 9, 30, 10)),
      ]);
      expect(find.text('2 sin leer'), findsOneWidget);

      await swipeLeft(tester, 'a');
      await tester.tap(find.byKey(const Key('notification-delete-a')));
      await tester.pumpAndSettle();

      expect(harness.repository.deletedIds, ['a']);
      expect(harness.repository.clearCalls, 0);
      expect(find.byKey(const Key('notification-a')), findsNothing);
      expect(find.byKey(const Key('notification-b')), findsOneWidget);
      expect(find.text('1 sin leer'), findsOneWidget);
      expect(harness.opened, isEmpty);
    });

    testWidgets('screen readers can delete through a semantics action', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final harness = await pumpScreen(tester, [testNotification(id: 'a')]);

      tester.semantics.customAction(
        find.semantics.byPredicate(
          (node) => node.getSemanticsData().customSemanticsActionIds!.contains(
            CustomSemanticsAction.getIdentifier(
              const CustomSemanticsAction(label: 'Eliminar notificación'),
            ),
          ),
        ),
        const CustomSemanticsAction(label: 'Eliminar notificación'),
      );
      await tester.pumpAndSettle();

      expect(harness.repository.deletedIds, ['a']);
      expect(find.text('Sin notificaciones'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('clear all asks first and can be cancelled', (tester) async {
      final harness = await pumpScreen(tester, [
        testNotification(id: 'a'),
        testNotification(id: 'b'),
      ]);

      await tester.tap(find.byKey(const Key('notifications-clear-all')));
      await tester.pumpAndSettle();
      expect(find.text('¿Vaciar notificaciones?'), findsOneWidget);

      await tester.tap(find.byKey(const Key('notifications-clear-cancel')));
      await tester.pumpAndSettle();

      expect(find.text('¿Vaciar notificaciones?'), findsNothing);
      expect(harness.repository.clearCalls, 0);
      expect(harness.repository.notifications, hasLength(2));
      expect(find.byKey(const Key('notification-a')), findsOneWidget);
    });

    testWidgets('clear all deletes every notification after confirming', (
      tester,
    ) async {
      final harness = await pumpScreen(tester, [
        testNotification(id: 'a'),
        testNotification(id: 'b', read: true),
      ]);

      await tester.tap(find.byKey(const Key('notifications-clear-all')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('notifications-clear-confirm')));
      await tester.pumpAndSettle();

      expect(harness.repository.clearCalls, 1);
      expect(harness.repository.deletedIds, isEmpty);
      expect(harness.repository.notifications, isEmpty);
      expect(find.text('Sin notificaciones'), findsOneWidget);
      final button = tester.widget<IconButton>(
        find.byKey(const Key('notifications-clear-all')),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('keeps the notification and warns if deletion fails', (
      tester,
    ) async {
      final harness = await pumpScreen(tester, [
        testNotification(id: 'a'),
      ], deleteFailure: StateError('permission-denied'));

      await swipeLeft(tester, 'a');
      await tester.tap(find.byKey(const Key('notification-delete-a')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('notification-a')), findsOneWidget);
      expect(
        find.text('No hemos podido eliminar la notificación.'),
        findsOneWidget,
      );
      expect(harness.repository.notifications, hasLength(1));
    });

    testWidgets('deleted notifications stay deleted after reopening', (
      tester,
    ) async {
      final harness = await pumpScreen(tester, [
        testNotification(id: 'a', createdAt: DateTime(2026, 9, 30, 11)),
        testNotification(id: 'b', createdAt: DateTime(2026, 9, 30, 10)),
      ]);
      await swipeLeft(tester, 'a');
      await tester.tap(find.byKey(const Key('notification-delete-a')));
      await tester.pumpAndSettle();

      // Same backing store, brand new view model and screen.
      await tester.pumpWidget(const SizedBox());
      await pumpScreen(tester, const [], existing: harness.repository);

      expect(find.byKey(const Key('notification-a')), findsNothing);
      expect(find.byKey(const Key('notification-b')), findsOneWidget);
    });

    testWidgets('empty state', (tester) async {
      await pumpScreen(tester, const []);

      expect(find.text('Sin notificaciones'), findsOneWidget);
      final button = tester.widget<IconButton>(
        find.byKey(const Key('notifications-mark-all')),
      );
      expect(button.onPressed, isNull);
      final clear = tester.widget<IconButton>(
        find.byKey(const Key('notifications-clear-all')),
      );
      expect(clear.onPressed, isNull);
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
