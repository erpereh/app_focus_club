import 'package:app_focus_club/features/auth/application/auth_scope.dart';
import 'package:app_focus_club/features/client/application/portal_scope.dart';
import 'package:app_focus_club/features/client/data/portal_repository.dart';
import 'package:app_focus_club/features/client/presentation/client_shell_screen.dart';
import 'package:app_focus_club/features/notifications/application/notification_navigator.dart';
import 'package:app_focus_club/features/notifications/application/notifications_scope.dart';
import 'package:app_focus_club/features/notifications/data/notifications_repository.dart';
import 'package:app_focus_club/features/notifications/domain/notification_models.dart';
import 'package:app_focus_club/features/support/application/support_scope.dart';
import 'package:app_focus_club/features/support/data/support_repository.dart';
import 'package:app_focus_club/features/support/presentation/support_chat_screen.dart';
import 'package:app_focus_club/shared/widgets/focus_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/notification_fixtures.dart';

void main() {
  late NotificationNavigator navigator;
  late FakeNotificationsRepository notificationsRepository;

  setUp(() {
    navigator = NotificationNavigator();
    notificationsRepository = FakeNotificationsRepository(
      notifications: [
        testNotification(id: 'n-apt'),
        testNotification(
          id: 'n-chat',
          type: 'support_message',
          event: 'support_message',
          title: 'Nuevo mensaje de Focus Club',
          route: NotificationRoute.chat,
          params: const {'conversationId': 'conv-1'},
        ),
      ],
    );
  });

  Future<void> pumpShell(WidgetTester tester, {int initialTab = 0}) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AuthScope(
        repository: TestAuthRepository(),
        child: PortalScope(
          repository: FakePortalRepository(appointments: [testAppointment()]),
          child: SupportScope(
            repository: FakeSupportRepository(
              conversations: [testConversation],
            ),
            child: NotificationsScope(
              repository: notificationsRepository,
              child: MaterialApp(
                home: ClientShellScreen(
                  initialTabIndex: initialTab,
                  notificationNavigator: navigator,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  int selectedTab(WidgetTester tester) =>
      tester.widget<FocusBottomNav>(find.byType(FocusBottomNav)).selectedIndex;

  test('keeps the destination until a shell attaches', () async {
    const target = NotificationTarget(
      route: NotificationRoute.chat,
      conversationId: 'conv-1',
    );
    navigator.handle(target);
    expect(navigator.pending, target);

    final opened = <NotificationTarget>[];
    navigator.attach((target) async => opened.add(target));

    expect(opened, [target]);
    expect(navigator.pending, isNull);
  });

  test('clear drops a pending destination on logout', () {
    navigator.handle(const NotificationTarget(route: NotificationRoute.bono));
    navigator.clear();
    expect(navigator.pending, isNull);
  });

  testWidgets('pending appointment opens its detail after login', (
    tester,
  ) async {
    // Tap received before the shell existed (cold start / login).
    navigator.handle(
      const NotificationTarget(
        route: NotificationRoute.appointment,
        notificationId: 'n-apt',
        appointmentId: 'apt-1',
      ),
    );

    await pumpShell(tester);

    expect(find.text('Detalle de la Cita'), findsOneWidget);
    expect(navigator.pending, isNull);
    expect(notificationsRepository.markedRead, ['n-apt']);
  });

  testWidgets('unknown appointment falls back to Citas with a message', (
    tester,
  ) async {
    await pumpShell(tester);

    navigator.handle(
      const NotificationTarget(
        route: NotificationRoute.appointment,
        appointmentId: 'deleted-apt',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Detalle de la Cita'), findsNothing);
    expect(selectedTab(tester), ClientShellScreen.tabAppointments);
    expect(
      find.text(ClientShellScreen.unavailableAppointmentMessage),
      findsOneWidget,
    );
  });

  testWidgets('series notice opens the appointments list', (tester) async {
    await pumpShell(tester);

    navigator.handle(
      const NotificationTarget(
        route: NotificationRoute.appointments,
        seriesId: 's1',
      ),
    );
    await tester.pumpAndSettle();

    expect(selectedTab(tester), ClientShellScreen.tabAppointments);
  });

  testWidgets('bono notice opens Inicio with the bono card', (tester) async {
    await pumpShell(tester, initialTab: ClientShellScreen.tabAppointments);

    navigator.handle(
      const NotificationTarget(route: NotificationRoute.bono, bonoId: 'b1'),
    );
    await tester.pumpAndSettle();

    expect(selectedTab(tester), ClientShellScreen.tabHome);
  });

  testWidgets('chat notice opens the conversation', (tester) async {
    await pumpShell(tester);

    navigator.handle(
      const NotificationTarget(
        route: NotificationRoute.chat,
        notificationId: 'n-chat',
        conversationId: 'conv-1',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Duda sobre mi bono'), findsWidgets);
    expect(navigator.activeConversationId.value, 'conv-1');
    expect(notificationsRepository.markedRead, ['n-chat']);

    Navigator.of(tester.element(find.byType(SupportChatScreen))).pop();
    await tester.pumpAndSettle();
    expect(navigator.activeConversationId.value, isNull);
    expect(selectedTab(tester), ClientShellScreen.tabChat);
  });

  testWidgets('a new notice replaces the screen opened by a previous one', (
    tester,
  ) async {
    await pumpShell(tester);
    navigator.handle(
      const NotificationTarget(
        route: NotificationRoute.appointment,
        appointmentId: 'apt-1',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Detalle de la Cita'), findsOneWidget);

    navigator.handle(const NotificationTarget(route: NotificationRoute.bono));
    await tester.pumpAndSettle();

    expect(find.text('Detalle de la Cita'), findsNothing);
    expect(selectedTab(tester), ClientShellScreen.tabHome);
  });

  testWidgets('bell shows unread count and history opens the target', (
    tester,
  ) async {
    await pumpShell(tester);

    expect(
      find.byKey(const Key('dashboard-notifications-bell')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('dashboard-notifications-badge')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('dashboard-notifications-bell')));
    await tester.pumpAndSettle();
    expect(find.text('Notificaciones'), findsOneWidget);
    expect(find.text('2 sin leer'), findsOneWidget);

    await tester.tap(find.byKey(const Key('notification-n-apt')));
    await tester.pumpAndSettle();

    expect(find.text('Detalle de la Cita'), findsOneWidget);
    expect(notificationsRepository.markedRead, contains('n-apt'));

    await tester.tap(find.byIcon(Icons.arrow_back_rounded).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-home')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('dashboard-notifications-badge')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('shell without notifications scope keeps the profile button', (
    tester,
  ) async {
    await tester.pumpWidget(
      AuthScope(
        repository: TestAuthRepository(),
        child: PortalScope(
          repository: FakePortalRepository(),
          child: SupportScope(
            repository: FakeSupportRepository(),
            child: MaterialApp(
              home: ClientShellScreen(notificationNavigator: navigator),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dashboard-notifications-bell')), findsNothing);
    expect(find.byTooltip('Abrir perfil'), findsWidgets);
  });
}
