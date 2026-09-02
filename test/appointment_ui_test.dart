import 'dart:async';

import 'package:app_focus_club/features/client/application/client_portal_view_model.dart';
import 'package:app_focus_club/features/client/data/portal_repository.dart';
import 'package:app_focus_club/features/client/domain/madrid_date.dart';
import 'package:app_focus_club/features/client/domain/portal_models.dart';
import 'package:app_focus_club/features/client/presentation/appointment_detail_screen.dart';
import 'package:app_focus_club/features/client/presentation/appointments_screen.dart';
import 'package:app_focus_club/features/client/presentation/booking_screen.dart';
import 'package:app_focus_club/features/client/presentation/dashboard_screen.dart';
import 'package:app_focus_club/features/client/widgets/appointment_display.dart';
import 'package:app_focus_club/features/client/widgets/client_cards.dart';
import 'package:app_focus_club/shared/widgets/focus_buttons.dart';
import 'package:app_focus_club/shared/widgets/focus_empty_state.dart';
import 'package:app_focus_club/shared/widgets/focus_glass_card.dart';
import 'package:app_focus_club/theme/app_text_size.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/layout_harness.dart';

void main() {
  testWidgets('future pending appointment exposes modify and cancel actions', (
    tester,
  ) async {
    final repository = FakePortalRepository();
    final viewModel = ClientPortalViewModel(repository: repository, uid: 'uid');
    final appointment = _appointment(
      status: AppointmentStatus.pending,
      date: _madridTomorrow(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AppointmentDetailScreen(
          appointment: appointment,
          viewModel: viewModel,
        ),
      ),
    );
    expect(
      find.text(
        'Solicitud enviada. El equipo de Focus Club confirmará la cita.',
      ),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Modificar cita'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Modificar cita'), findsOneWidget);
    expect(find.text('Cancelar cita'), findsOneWidget);
  });

  testWidgets('appointment card shows the derived missed presentation', (
    tester,
  ) async {
    final appointment = _appointment(
      status: AppointmentStatus.pending,
      date: _wireDate(DateTime.now().subtract(const Duration(days: 1))),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClientAppointmentCard(appointment: appointment, onTap: () {}),
        ),
      ),
    );

    expect(find.text('No realizada'), findsOneWidget);
    expect(
      find.text('La hora de esta solicitud ha pasado sin confirmacion.'),
      findsOneWidget,
    );
  });

  testWidgets('appointment card keeps 07:00 on one line at 320 and 390', (
    tester,
  ) async {
    final appointment = _appointment(
      status: AppointmentStatus.pending,
      date: '2030-09-10',
      time: '07:00',
      assignedTrainer: 'Marta Entrenadora',
      recurrenceSeriesId: 'series-1',
    );

    Future<void> pumpAt(Size size, {double textScale = 1}) async {
      setLogicalViewport(tester, size);
      await tester.pumpWidget(
        MaterialApp(
          home: TextScaleHarness(
            textScaler: TextScaler.linear(textScale),
            child: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(20),
                child: ClientAppointmentCard(
                  appointment: appointment,
                  trainerName: 'Marta Entrenadora',
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpAt(kViewportSe);
    expect(find.byKey(const Key('appointment-start-time')), findsOneWidget);
    expectSingleLineText(
      tester,
      find.byKey(const Key('appointment-start-time')),
    );
    expect(find.text('07:00'), findsWidgets);
    expect(find.text('Pendiente'), findsOneWidget);
    expect(find.textContaining('Recurrente'), findsOneWidget);
    expectNoLayoutException(tester);

    await pumpAt(kViewportCompact);
    expectSingleLineText(
      tester,
      find.byKey(const Key('appointment-start-time')),
    );
    expectNoLayoutException(tester);

    await pumpAt(kViewportProMax);
    expectSingleLineText(
      tester,
      find.byKey(const Key('appointment-start-time')),
    );
    expectNoLayoutException(tester);

    await pumpAt(kViewportIphone14);
    expectSingleLineText(
      tester,
      find.byKey(const Key('appointment-start-time')),
    );
    expect(find.text('Pendiente'), findsOneWidget);
    expectNoLayoutException(tester);

    await pumpAt(kViewportSe, textScale: 1.3);
    expectSingleLineText(
      tester,
      find.byKey(const Key('appointment-start-time')),
    );
    expect(find.text('Pendiente'), findsOneWidget);
    expectNoLayoutException(tester);
  });

  testWidgets(
    'appointment card truncates a long description without overflow',
    (tester) async {
      setLogicalViewport(tester, kViewportSe);
      final appointment = Appointment(
        id: 'appointment-id',
        userId: 'uid',
        name: 'Cliente',
        email: 'cliente@example.com',
        phone: '+34612345678',
        serviceType:
            'Bono Mensual de Entrenamiento Personal Avanzado con movilidad',
        durationMinutes: 45,
        preferredSlots: const [TimeSlot(date: '2030-09-10', time: '07:00')],
        reason: '',
        status: AppointmentStatus.approved,
        createdAt: '2030-05-01T10:00:00.000Z',
        assignedTrainer: 'Entrenador con un nombre especialmente largo',
        recurrenceSeriesId: 'series-1',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(12),
              child: ClientAppointmentCard(
                appointment: appointment,
                trainerName: 'Entrenador con un nombre especialmente largo',
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expectSingleLineText(
        tester,
        find.byKey(const Key('appointment-start-time')),
      );
      expect(find.text('Aprobada'), findsOneWidget);
      expectNoLayoutException(tester);
    },
  );

  testWidgets('detail refreshes its presentation and actions at the boundary', (
    tester,
  ) async {
    var now = DateTime(2030, 5, 20, 9, 59);
    final appointment = _appointment(
      status: AppointmentStatus.approved,
      date: '2030-05-20',
    );
    final viewModel = ClientPortalViewModel(
      repository: FakePortalRepository(),
      uid: 'uid',
      now: () => now,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AppointmentDetailScreen(
          appointment: appointment,
          viewModel: viewModel,
        ),
      ),
    );
    expect(find.text('Aprobada'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text(sameDayChangeNotAllowedMessage),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(sameDayChangeNotAllowedMessage), findsOneWidget);
    expect(find.text('Modificar cita'), findsNothing);
    expect(find.text('Cancelar cita'), findsNothing);

    now = DateTime(2030, 5, 20, 10);
    viewModel.refreshTemporalState();
    await tester.pump();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 1000));
    await tester.pumpAndSettle();

    expect(find.text('Realizada'), findsOneWidget);
    expect(find.text('Esta cita ya se ha realizado.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text(sameDayChangeNotAllowedMessage),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(sameDayChangeNotAllowedMessage), findsOneWidget);
    expect(find.text('Modificar cita'), findsNothing);
    expect(find.text('Cancelar cita'), findsNothing);
    viewModel.dispose();
  });

  testWidgets('dashboard next appointment preview includes derived status', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final appointment = _appointment(
      status: AppointmentStatus.pending,
      date: _madridTomorrow(),
    );
    final viewModel = ClientPortalViewModel(
      repository: FakePortalRepository(),
      uid: 'uid',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardScreen(
            state: ClientPortalState(
              appointments: [appointment],
              isLoading: false,
            ),
            viewModel: viewModel,
            onOpenAppointments: () {},
            onOpenProfile: () {},
            onOpenBooking: () {},
          ),
        ),
      ),
    );
    final preview = find.ancestor(
      of: find.text('PROXIMA CITA'),
      matching: find.byType(FocusBlackCard),
    );
    expect(preview, findsOneWidget);
    expect(
      find.descendant(of: preview, matching: find.text('Pendiente')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: preview,
        matching: find.text(
          'Solicitud enviada. El equipo de Focus Club confirmará la cita.',
        ),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: preview,
        matching: find.text(
          'Solicitud enviada. El equipo de Focus Club confirmara la franja.',
        ),
      ),
      findsNothing,
    );
    expect(
      find.descendant(of: preview, matching: find.text(appointment.dateLabel)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: preview,
        matching: find.text(
          '${appointment.timeLabel} - ${appointment.durationMinutes} min',
        ),
      ),
      findsOneWidget,
    );
    viewModel.dispose();
  });

  testWidgets('dashboard history shows only the two latest occurred sessions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime.now();
    final latest = _appointment(
      id: 'latest',
      status: AppointmentStatus.approved,
      date: _wireDate(now.subtract(const Duration(days: 1))),
      createdAt: '2020-01-01T08:00:00.000Z',
    );
    final second = _appointment(
      id: 'second',
      status: AppointmentStatus.pending,
      date: _wireDate(now.subtract(const Duration(days: 2))),
      createdAt: '2040-01-01T08:00:00.000Z',
    );
    final older = _appointment(
      id: 'older',
      status: AppointmentStatus.approved,
      date: _wireDate(now.subtract(const Duration(days: 3))),
    );
    final futureCancelled = _appointment(
      id: 'future-cancelled',
      status: AppointmentStatus.cancelled,
      date: _wireDate(now.add(const Duration(days: 5))),
    );
    final futureRejected = _appointment(
      id: 'future-rejected',
      status: AppointmentStatus.rejected,
      date: _wireDate(now.add(const Duration(days: 4))),
    );
    final viewModel = ClientPortalViewModel(
      repository: FakePortalRepository(),
      uid: 'uid',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppointmentsScreen(
            state: ClientPortalState(
              appointments: [
                futureCancelled,
                older,
                latest,
                futureRejected,
                second,
              ],
              isLoading: false,
            ),
            viewModel: viewModel,
            onOpenBooking: () {},
          ),
        ),
      ),
    );
    await tester.tap(find.text('Historial'));
    await tester.pumpAndSettle();

    final latestSchedule =
        '${latest.timeLabel} - ${latest.durationMinutes} min';
    final secondSchedule =
        '${second.timeLabel} - ${second.durationMinutes} min';
    expect(find.text(latest.dateLabel), findsOneWidget);
    expect(find.text(second.dateLabel), findsOneWidget);
    expect(find.text(older.dateLabel), findsOneWidget);
    expect(find.text(latestSchedule), findsWidgets);
    expect(find.text(secondSchedule), findsWidgets);
    expect(
      tester.getTopLeft(find.text(latest.dateLabel)).dy,
      lessThan(tester.getTopLeft(find.text(second.dateLabel)).dy),
    );
    expect(
      tester.getTopLeft(find.text(second.dateLabel)).dy,
      lessThan(tester.getTopLeft(find.text(older.dateLabel)).dy),
    );
    viewModel.dispose();
  });

  testWidgets(
    'appointments history can scroll its empty pass history above navigation',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(bottom: 24);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      final now = DateTime.now();
      final viewModel = ClientPortalViewModel(
        repository: FakePortalRepository(),
        uid: 'uid',
      );

      await tester.pumpWidget(
        _LargeTextHarness(
          child: Scaffold(
            body: AppointmentsScreen(
              state: ClientPortalState(
                appointments: [
                  _appointment(
                    id: 'past-1',
                    status: AppointmentStatus.approved,
                    date: _wireDate(now.subtract(const Duration(days: 1))),
                  ),
                  _appointment(
                    id: 'past-2',
                    status: AppointmentStatus.pending,
                    date: _wireDate(now.subtract(const Duration(days: 2))),
                  ),
                ],
                isLoading: false,
              ),
              viewModel: viewModel,
              onOpenBooking: () {},
            ),
          ),
        ),
      );
      await tester.tap(find.text('Historial'));
      await tester.pumpAndSettle();

      final listFinder = find.byKey(const Key('appointments-list'));
      expect(listFinder, findsOneWidget);
      final listContext = tester.element(listFinder);
      final reservedBottom =
          MediaQuery.paddingOf(listContext).bottom +
          AppTextSizing.navigationItemMinHeight(listContext) +
          12 +
          28;
      final listView = tester.widget<ListView>(listFinder);
      expect(
        listView.padding!.resolve(TextDirection.ltr).bottom,
        reservedBottom,
      );

      await tester.drag(listFinder, const Offset(0, -2000));
      await tester.pumpAndSettle();
      final emptyState = find.ancestor(
        of: find.text('Sin historial de bonos'),
        matching: find.byType(FocusEmptyState),
      );
      expect(emptyState, findsOneWidget);
      expect(
        tester.getBottomRight(emptyState).dy,
        lessThanOrEqualTo(568 - reservedBottom),
      );
      viewModel.dispose();
    },
  );

  testWidgets('appointments history can scroll pass cards above navigation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(bottom: 24);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    final viewModel = ClientPortalViewModel(
      repository: FakePortalRepository(),
      uid: 'uid',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppointmentsScreen(
            state: ClientPortalState(
              bonos: [_bono(status: BonoStatus.agotado)],
              isLoading: false,
            ),
            viewModel: viewModel,
            onOpenBooking: () {},
          ),
        ),
      ),
    );
    await tester.tap(find.text('Historial'));
    await tester.pumpAndSettle();

    final listFinder = find.byKey(const Key('appointments-list'));
    expect(listFinder, findsOneWidget);
    final listContext = tester.element(listFinder);
    final reservedBottom =
        MediaQuery.paddingOf(listContext).bottom +
        AppTextSizing.navigationItemMinHeight(listContext) +
        12 +
        28;
    final passHistoryTitle = find.text('Historial de bonos');
    for (var attempt = 0; attempt < 12; attempt++) {
      final titleIsClear =
          passHistoryTitle.evaluate().isNotEmpty &&
          tester.getBottomRight(passHistoryTitle).dy <= 568 - reservedBottom;
      if (titleIsClear) break;
      await tester.drag(listFinder, const Offset(0, -80));
      await tester.pumpAndSettle();
    }
    expect(passHistoryTitle, findsOneWidget);
    expect(
      tester.getBottomRight(passHistoryTitle).dy,
      lessThanOrEqualTo(568 - reservedBottom),
    );

    await tester.drag(listFinder, const Offset(0, -1200));
    await tester.pumpAndSettle();

    final passCard = find.byType(PassHistoryCard);
    expect(passCard, findsOneWidget);
    expect(
      tester.getBottomRight(passCard).dy,
      lessThanOrEqualTo(568 - reservedBottom),
    );
    viewModel.dispose();
  });

  testWidgets(
    'past and cancelled appointments do not expose appointment actions',
    (tester) async {
      final repository = FakePortalRepository();
      final viewModel = ClientPortalViewModel(
        repository: repository,
        uid: 'uid',
      );
      final appointment = _appointment(
        status: AppointmentStatus.cancelled,
        date: _wireDate(DateTime.now().subtract(const Duration(days: 1))),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AppointmentDetailScreen(
            appointment: appointment,
            viewModel: viewModel,
          ),
        ),
      );

      expect(find.text('Modificar cita'), findsNothing);
      expect(find.text('Cancelar cita'), findsNothing);
    },
  );

  testWidgets('cancelling an appointment calls the repository action', (
    tester,
  ) async {
    final repository = FakePortalRepository();
    final viewModel = ClientPortalViewModel(repository: repository, uid: 'uid');
    final appointment = _appointment(
      status: AppointmentStatus.approved,
      date: _madridTomorrow(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AppointmentDetailScreen(
          appointment: appointment,
          viewModel: viewModel,
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Cancelar cita'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Cancelar cita'));
    await tester.pumpAndSettle();

    expect(find.text('¿Cancelar esta cita?'), findsOneWidget);
    final backButton = find.widgetWithText(OutlinedButton, 'Volver');
    final cancelButton = find.widgetWithText(FilledButton, 'Cancelar cita');
    expect(backButton, findsOneWidget);
    expect(cancelButton, findsOneWidget);
    expect(tester.getSize(backButton).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(cancelButton).height, greaterThanOrEqualTo(48));
    expect(
      tester.getSize(backButton).width,
      tester.getSize(cancelButton).width,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Cancelar cita'));
    await tester.pumpAndSettle();

    expect(repository.cancelledAppointmentIds, [appointment.id]);
  });

  testWidgets('booking time slots always use three columns', (tester) async {
    final repository = FakePortalRepository(
      bonos: [_bono()],
      siteConfig: const SiteConfig(
        startHour: 8,
        endHour: 20,
        slotInterval: 30,
        bonoExpirationMonths: 1,
        maintenanceMode: false,
      ),
    );
    final viewModel = ClientPortalViewModel(repository: repository, uid: 'uid')
      ..start();
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _LargeTextHarness(child: BookingScreen(viewModel: viewModel)),
    );
    await tester.pumpAndSettle();
    await _bookingContinueUntil(
      tester,
      find.byKey(const Key('booking-slot-grid')),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('booking-slot-grid')),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    final gridFinder = find.byKey(const Key('booking-slot-grid'));
    expect(gridFinder, findsOneWidget);
    final grid = tester.widget<GridView>(gridFinder);
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 3);
    expect(tester.takeException(), isNull);
    viewModel.dispose();
  });

  testWidgets('large text adapts appointment detail and cancel dialog', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = FakePortalRepository();
    final viewModel = ClientPortalViewModel(repository: repository, uid: 'uid');
    final appointment = _appointment(
      status: AppointmentStatus.approved,
      date: _madridTomorrow(),
    );

    await tester.pumpWidget(
      _LargeTextHarness(
        child: AppointmentDetailScreen(
          appointment: appointment,
          viewModel: viewModel,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Servicio'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    final serviceLabel = tester.getTopLeft(find.text('Servicio'));
    final serviceValue = tester.getTopLeft(
      find.text('Bono Mensual de Entrenamiento').last,
    );
    expect(serviceValue.dy, greaterThan(serviceLabel.dy));

    await tester.scrollUntilVisible(
      find.text('Cancelar cita'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Cancelar cita'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<AlertDialog>(find.byType(AlertDialog)).scrollable,
      true,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing keeps duration fixed and updates the selected slot', (
    tester,
  ) async {
    final appointment = _appointment(
      status: AppointmentStatus.pending,
      date: _madridTomorrow(),
    );
    final repository = FakePortalRepository(
      appointments: [appointment],
      siteConfig: const SiteConfig(
        startHour: 8,
        endHour: 20,
        slotInterval: 30,
        bonoExpirationMonths: 1,
        maintenanceMode: false,
      ),
    );
    final viewModel = ClientPortalViewModel(repository: repository, uid: 'uid')
      ..start();

    await tester.pumpWidget(
      MaterialApp(
        home: BookingScreen(
          viewModel: viewModel,
          editingAppointment: appointment,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Modificar cita'), findsOneWidget);
    expect(find.text('Duración fija: 45 min'), findsOneWidget);
    expect(find.text('Enviar Solicitud'), findsNothing);
    await _bookingContinueUntil(tester, find.text('Guardar cambios'));
    await tester.scrollUntilVisible(
      find.text('Guardar cambios'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Guardar cambios'));
    await tester.pump();

    expect(repository.slotUpdates, hasLength(1));
    expect(repository.slotUpdates.single.appointmentId, appointment.id);
    await tester.pump(const Duration(milliseconds: 901));
    await tester.pumpAndSettle();
    viewModel.dispose();
  });

  testWidgets('booking defaults to a single appointment', (tester) async {
    final viewModel = _bookingViewModel();
    await tester.pumpWidget(
      MaterialApp(home: BookingScreen(viewModel: viewModel)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cita única'), findsOneWidget);
    expect(find.text('Entrenamiento recurrente'), findsOneWidget);
    expect(find.text('Cada'), findsNothing);
    expect(find.text('Hasta'), findsNothing);
    viewModel.dispose();
  });

  testWidgets('recurring booking shows interval and Hasta controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final viewModel = _bookingViewModel();
    await tester.pumpWidget(
      MaterialApp(home: BookingScreen(viewModel: viewModel)),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('booking-type-recurring')));
    await tester.tap(find.byKey(const Key('booking-type-recurring')));
    await tester.pumpAndSettle();
    await _bookingSelectSlot(tester, dateLabel: '10 sep');
    await _bookingContinueUntil(tester, find.text('Cada'));
    await tester.scrollUntilVisible(
      find.text('Cada'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Cada'), findsOneWidget);
    expect(find.text('Hasta'), findsOneWidget);
    expect(find.text('días'), findsOneWidget);
    viewModel.dispose();
  });

  testWidgets('booking flow stays stable at 320px with large text', (
    tester,
  ) async {
    setLogicalViewport(tester, const Size(320, 1800));
    final viewModel = _bookingViewModel();
    await tester.pumpWidget(
      _LargeTextHarness(child: BookingScreen(viewModel: viewModel)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Cita única'), findsOneWidget);
    expectNoLayoutException(tester);

    await tester.ensureVisible(find.byKey(const Key('booking-type-recurring')));
    await tester.tap(find.byKey(const Key('booking-type-recurring')));
    await tester.pumpAndSettle();
    expectNoLayoutException(tester);

    await _bookingContinueUntil(tester, find.text('10 sep'));
    await tester.scrollUntilVisible(
      find.text('10 sep'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('10 sep'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('18:00').first,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('18:00').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('booking-slot-grid')), findsOneWidget);
    expectNoLayoutException(tester);

    await _bookingContinueUntil(tester, find.text('Cada'));
    await tester.scrollUntilVisible(
      find.text('Hasta'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('días'), findsOneWidget);
    expect(find.text('Hasta'), findsOneWidget);
    expectNoLayoutException(tester);

    await _bookingContinueUntil(
      tester,
      find.byKey(const Key('recurring-end-date')),
    );
    await _selectRecurringHasta(tester, '2026-09-19');
    expect(find.textContaining('sesiones'), findsWidgets);
    expectNoLayoutException(tester);

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Enviar Solicitud'), findsOneWidget);
    expectNoLayoutException(tester);
    viewModel.dispose();
  });

  testWidgets('switching back to a single booking ignores leftover endDate', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _bookingRepository();
    final viewModel = _bookingViewModel(repository: repository);
    await tester.pumpWidget(
      MaterialApp(home: BookingScreen(viewModel: viewModel)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('booking-type-recurring')));
    await tester.pumpAndSettle();
    await _bookingContinueUntil(tester, find.text('60'));
    await tester.tap(find.text('60'));
    await tester.pumpAndSettle();
    await _bookingContinueUntil(tester, find.text('10 sep'));
    await tester.tap(find.text('10 sep'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('18:00').first);
    await tester.pumpAndSettle();
    await _bookingContinueUntil(
      tester,
      find.byKey(const Key('recurring-end-date')),
    );
    await _selectRecurringHasta(tester, '2026-09-19');

    await tester.tap(find.text('Atras'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Atras'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Atras'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('booking-type-single')));
    await tester.pumpAndSettle();
    expect(find.text('Cada'), findsNothing);
    expect(find.text('Hasta'), findsNothing);

    await tester.tap(find.byKey(const Key('booking-type-recurring')));
    await tester.pumpAndSettle();
    await _bookingContinueUntil(tester, find.text('Cada'));
    expect(find.text('Cada'), findsOneWidget);
    expect(find.text('4 sesiones'), findsNothing);
    await tester.tap(find.text('Atras'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Atras'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Atras'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('booking-type-single')));
    await tester.pumpAndSettle();

    await _bookingContinueUntil(tester, find.text('18:00'));
    await tester.tap(find.text('18:00').first);
    await tester.pumpAndSettle();
    await _bookingContinueUntil(tester, find.text('Enviar Solicitud'));
    await tester.tap(find.text('Enviar Solicitud'));
    await tester.pump();
    expect(repository.requests, hasLength(1));
    expect(repository.recurringRequests, isEmpty);
    await tester.pump(const Duration(milliseconds: 901));
    await tester.pumpAndSettle();
    viewModel.dispose();
  });

  testWidgets('recurring submit uses createRecurringAppointments once', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _bookingRepository();
    final viewModel = _bookingViewModel(repository: repository);
    await tester.pumpWidget(
      MaterialApp(home: BookingScreen(viewModel: viewModel)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('booking-type-recurring')));
    await tester.pumpAndSettle();
    await _bookingContinueUntil(tester, find.text('60'));
    await tester.tap(find.text('60'));
    await tester.pumpAndSettle();
    await _bookingContinueUntil(tester, find.text('10 sep'));
    await tester.tap(find.text('10 sep'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('18:00').first);
    await tester.pumpAndSettle();
    await _bookingContinueUntil(
      tester,
      find.byKey(const Key('recurring-end-date')),
    );
    await _selectRecurringHasta(tester, '2026-09-19');
    expect(find.text('4 sesiones'), findsWidgets);
    expect(find.text('60 min por sesión'), findsOneWidget);
    expect(find.text('240 min en total'), findsOneWidget);
    expect(
      find.text('Las sesiones quedarán pendientes de aprobación.'),
      findsOneWidget,
    );

    await _bookingContinueUntil(tester, find.text('Enviar Solicitud'));
    await tester.tap(find.text('Enviar Solicitud'));
    await tester.pump();
    expect(repository.recurringRequests, hasLength(1));
    expect(repository.requests, isEmpty);
    expect(repository.recurringRequests.single.intervalDays, 3);
    expect(repository.recurringRequests.single.endDate, '2026-09-19');
    expect(repository.recurringRequests.single.durationMinutes, 60);
    await tester.pump(const Duration(milliseconds: 901));
    await tester.pumpAndSettle();
    viewModel.dispose();
  });

  testWidgets('recurring submit stays disabled without two sessions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final viewModel = _bookingViewModel(
      repository: _bookingRepository(bono: _bonoWithMinutes(60)),
    );
    await tester.pumpWidget(
      MaterialApp(home: BookingScreen(viewModel: viewModel)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('booking-type-recurring')));
    await tester.pumpAndSettle();
    await _bookingContinueUntil(tester, find.text('60'));
    await tester.tap(find.text('60'));
    await tester.pumpAndSettle();
    await _bookingSelectSlot(tester, dateLabel: '10 sep');
    await _bookingContinueUntil(
      tester,
      find.text(
        'No tienes minutos o vigencia suficientes para programar al menos 2 sesiones.',
      ),
    );

    expect(
      find.text(
        'No tienes minutos o vigencia suficientes para programar al menos 2 sesiones.',
      ),
      findsOneWidget,
    );
    await _bookingContinueUntil(tester, find.text('Enviar Solicitud'));
    await tester.scrollUntilVisible(
      find.text('Enviar Solicitud'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    final submit = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Enviar Solicitud'),
    );
    expect(submit.onPressed, isNull);
    viewModel.dispose();
  });

  testWidgets('changing interval clears an obsolete Hasta date', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final viewModel = _bookingViewModel(now: DateTime(2026, 9, 8, 9));
    await tester.pumpWidget(
      MaterialApp(home: BookingScreen(viewModel: viewModel)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('booking-type-recurring')));
    await tester.pumpAndSettle();
    await _bookingContinueUntil(tester, find.text('30'));
    await tester.tap(find.text('30'));
    await tester.pumpAndSettle();
    await _bookingSelectSlot(tester, dateLabel: '08 sep');
    await _bookingContinueUntil(
      tester,
      find.byKey(const Key('recurring-interval-days')),
    );
    await tester.enterText(
      find.byKey(const Key('recurring-interval-days')),
      '7',
    );
    await tester.pumpAndSettle();
    await _selectRecurringHasta(tester, '2026-09-29');
    expect(find.text('4 sesiones'), findsWidgets);

    await tester.enterText(
      find.byKey(const Key('recurring-interval-days')),
      '10',
    );
    await tester.pumpAndSettle();
    expect(find.text('4 sesiones'), findsNothing);
    expect(find.text('29/09/2026 · 4 sesiones · 120 min'), findsNothing);
    viewModel.dispose();
  });

  testWidgets('recurring Hasta loading disables continue', (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gate = Completer<void>();
    final repository = _bookingRepository(availabilityGate: gate);
    final viewModel = _bookingViewModel(repository: repository);
    await tester.pumpWidget(
      MaterialApp(home: BookingScreen(viewModel: viewModel)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('booking-type-recurring')));
    await tester.pumpAndSettle();
    await _bookingContinueUntil(tester, find.text('60'));
    await tester.tap(find.text('60'));
    await tester.pumpAndSettle();
    await _bookingSelectSlot(tester, dateLabel: '10 sep');
    await _bookingContinueUntil(
      tester,
      find.byKey(const Key('recurring-end-date')),
    );
    await tester.pump();

    expect(find.text('Comprobando disponibilidad...'), findsWidgets);
    final continueButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continuar'),
    );
    expect(continueButton.onPressed, isNull);

    gate.complete();
    await tester.pumpAndSettle();
    viewModel.dispose();
  });

  testWidgets('recurring Hasta shows available options as selectable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final viewModel = _bookingViewModel();
    await tester.pumpWidget(
      MaterialApp(home: BookingScreen(viewModel: viewModel)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('booking-type-recurring')));
    await tester.pumpAndSettle();
    await _bookingContinueUntil(tester, find.text('60'));
    await tester.tap(find.text('60'));
    await tester.pumpAndSettle();
    await _bookingSelectSlot(tester, dateLabel: '10 sep');
    await _bookingContinueUntil(
      tester,
      find.byKey(const Key('recurring-end-date')),
    );
    await tester.tap(find.byKey(const Key('recurring-end-date')));
    await tester.pumpAndSettle();

    expect(find.text('Disponible'), findsWidgets);
    await tester.tap(
      find.byKey(const Key('recurring-hasta-option-2026-09-13')),
    );
    await tester.pumpAndSettle();
    expect(find.text('2 sesiones'), findsWidgets);
    viewModel.dispose();
  });

  testWidgets('recurring Hasta blocked option is visible and not selectable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _bookingRepository(
      blockedSlots: const [
        BlockedSlot(id: 'block-16', date: '2026-09-16', time: '18:00'),
      ],
    );
    final viewModel = _bookingViewModel(repository: repository);
    await tester.pumpWidget(
      MaterialApp(home: BookingScreen(viewModel: viewModel)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('booking-type-recurring')));
    await tester.pumpAndSettle();
    await _bookingContinueUntil(tester, find.text('60'));
    await tester.tap(find.text('60'));
    await tester.pumpAndSettle();
    await _bookingSelectSlot(tester, dateLabel: '10 sep');
    await _bookingContinueUntil(
      tester,
      find.byKey(const Key('recurring-end-date')),
    );
    await tester.tap(find.byKey(const Key('recurring-end-date')));
    await tester.pumpAndSettle();

    expect(find.text('La sesión del 16/09 está bloqueada.'), findsWidgets);
    final blockedTile = tester.widget<ListTile>(
      find.byKey(const Key('recurring-hasta-option-2026-09-16')),
    );
    expect(blockedTile.enabled, isFalse);
    final laterTile = tester.widget<ListTile>(
      find.byKey(const Key('recurring-hasta-option-2026-09-19')),
    );
    expect(laterTile.enabled, isFalse);
    await tester.tap(
      find.byKey(const Key('recurring-hasta-option-2026-09-16')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsWidgets);
    viewModel.dispose();
  });

  testWidgets('recurring Hasta full option is visible and not selectable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _bookingRepository(
      slotOccupancy: const [
        SlotOccupancy(
          id: '2026-09-16_18:00',
          date: '2026-09-16',
          time: '18:00',
          count: 2,
        ),
      ],
    );
    final viewModel = _bookingViewModel(repository: repository);
    await tester.pumpWidget(
      MaterialApp(home: BookingScreen(viewModel: viewModel)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('booking-type-recurring')));
    await tester.pumpAndSettle();
    await _bookingContinueUntil(tester, find.text('60'));
    await tester.tap(find.text('60'));
    await tester.pumpAndSettle();
    await _bookingSelectSlot(tester, dateLabel: '10 sep');
    await _bookingContinueUntil(
      tester,
      find.byKey(const Key('recurring-end-date')),
    );
    await tester.tap(find.byKey(const Key('recurring-end-date')));
    await tester.pumpAndSettle();

    expect(find.text('Franja completa el 16/09'), findsWidgets);
    expect(
      tester
          .widget<ListTile>(
            find.byKey(const Key('recurring-hasta-option-2026-09-16')),
          )
          .enabled,
      isFalse,
    );
    viewModel.dispose();
  });

  testWidgets('recurring Hasta conflict option is visible and not selectable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _bookingRepository(
      appointments: [
        _appointment(
          status: AppointmentStatus.approved,
          date: '2026-09-16',
          time: '18:00',
        ),
      ],
    );
    final viewModel = _bookingViewModel(repository: repository);
    await tester.pumpWidget(
      MaterialApp(home: BookingScreen(viewModel: viewModel)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('booking-type-recurring')));
    await tester.pumpAndSettle();
    await _bookingContinueUntil(tester, find.text('60'));
    await tester.tap(find.text('60'));
    await tester.pumpAndSettle();
    await _bookingSelectSlot(tester, dateLabel: '10 sep');
    await _bookingContinueUntil(
      tester,
      find.byKey(const Key('recurring-end-date')),
    );
    await tester.tap(find.byKey(const Key('recurring-end-date')));
    await tester.pumpAndSettle();

    expect(
      find.text('Ya tienes una sesión que se solapa el 16/09/2026.'),
      findsWidgets,
    );
    expect(
      tester
          .widget<ListTile>(
            find.byKey(const Key('recurring-hasta-option-2026-09-16')),
          )
          .enabled,
      isFalse,
    );
    viewModel.dispose();
  });

  testWidgets('recurring Hasta preview error allows selection and submit', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _bookingRepository(
      availabilityFailure: Exception('offline'),
    );
    final viewModel = _bookingViewModel(repository: repository);
    await tester.pumpWidget(
      MaterialApp(home: BookingScreen(viewModel: viewModel)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('booking-type-recurring')));
    await tester.pumpAndSettle();
    await _bookingContinueUntil(tester, find.text('60'));
    await tester.tap(find.text('60'));
    await tester.pumpAndSettle();
    await _bookingSelectSlot(tester, dateLabel: '10 sep');
    await _bookingContinueUntil(
      tester,
      find.byKey(const Key('recurring-end-date')),
    );
    expect(
      find.text('No se ha podido comprobar la disponibilidad.'),
      findsWidgets,
    );

    await _selectRecurringHasta(tester, '2026-09-19');
    expect(find.text('4 sesiones'), findsWidgets);
    expect(
      find.text(
        'No se ha podido comprobar la disponibilidad. Se volverá a validar al enviar.',
      ),
      findsOneWidget,
    );

    await _bookingContinueUntil(tester, find.text('Enviar Solicitud'));
    await tester.tap(find.text('Enviar Solicitud'));
    await tester.pump();
    expect(repository.recurringRequests, hasLength(1));
    expect(repository.recurringRequests.single.endDate, '2026-09-19');
    await tester.pump(const Duration(milliseconds: 901));
    await tester.pumpAndSettle();
    viewModel.dispose();
  });

  testWidgets('changing interval reloads recurring availability', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _bookingRepository();
    final viewModel = _bookingViewModel(repository: repository);
    await tester.pumpWidget(
      MaterialApp(home: BookingScreen(viewModel: viewModel)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('booking-type-recurring')));
    await tester.pumpAndSettle();
    await _bookingContinueUntil(tester, find.text('60'));
    await tester.tap(find.text('60'));
    await tester.pumpAndSettle();
    await _bookingSelectSlot(tester, dateLabel: '10 sep');
    await _bookingContinueUntil(
      tester,
      find.byKey(const Key('recurring-interval-days')),
    );
    final callsAfterSlot = repository.availabilityCalls;
    expect(callsAfterSlot, greaterThan(0));

    await tester.enterText(
      find.byKey(const Key('recurring-interval-days')),
      '7',
    );
    await tester.pumpAndSettle();
    expect(repository.availabilityCalls, greaterThan(callsAfterSlot));
    viewModel.dispose();
  });

  testWidgets('invalid Hasta after ready preview is cleared', (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _bookingRepository();
    final viewModel = _bookingViewModel(repository: repository);
    await tester.pumpWidget(
      MaterialApp(home: BookingScreen(viewModel: viewModel)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('booking-type-recurring')));
    await tester.pumpAndSettle();
    await _bookingContinueUntil(tester, find.text('60'));
    await tester.tap(find.text('60'));
    await tester.pumpAndSettle();
    await _bookingSelectSlot(tester, dateLabel: '10 sep');
    await _bookingContinueUntil(
      tester,
      find.byKey(const Key('recurring-end-date')),
    );
    await _selectRecurringHasta(tester, '2026-09-19');
    expect(find.text('4 sesiones'), findsWidgets);

    repository.emitAppointments([
      _appointment(
        status: AppointmentStatus.pending,
        date: '2026-09-16',
        time: '18:00',
      ),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('4 sesiones'), findsNothing);
    viewModel.dispose();
  });

  testWidgets('pending recurring detail cancels the whole series', (
    tester,
  ) async {
    final appointment = _appointment(
      status: AppointmentStatus.pending,
      date: _madridTomorrow(),
      recurrenceSeriesId: 'series-1',
      recurrenceIndex: 0,
    );
    final series = _series(id: 'series-1');
    final repository = FakePortalRepository(
      appointments: [appointment],
      recurringSeries: [series],
    );
    final viewModel = ClientPortalViewModel(repository: repository, uid: 'uid')
      ..start();

    await tester.pumpWidget(
      MaterialApp(
        home: AppointmentDetailScreen(
          appointment: appointment,
          viewModel: viewModel,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Entrenamiento recurrente'), findsOneWidget);
    expect(find.text('Cada'), findsOneWidget);
    expect(find.text('3 días'), findsOneWidget);
    expect(find.text('Modificar cita'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Cancelar solicitud recurrente'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Cancelar cita'), findsNothing);
    await tester.tap(find.text('Cancelar solicitud recurrente'));
    await tester.pumpAndSettle();
    expect(
      find.text('¿Cancelar toda la solicitud recurrente?'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Cancelar solicitud'));
    await tester.pumpAndSettle();
    expect(repository.cancelledSeriesIds, ['series-1']);
    expect(repository.cancelledAppointmentIds, isEmpty);
    viewModel.dispose();
  });

  testWidgets('approved recurring detail cancels only that occurrence', (
    tester,
  ) async {
    final appointment = _appointment(
      status: AppointmentStatus.approved,
      date: _madridTomorrow(),
      recurrenceSeriesId: 'series-1',
      recurrenceIndex: 1,
    );
    final viewModel = ClientPortalViewModel(
      repository: FakePortalRepository(appointments: [appointment]),
      uid: 'uid',
    )..start();

    await tester.pumpWidget(
      MaterialApp(
        home: AppointmentDetailScreen(
          appointment: appointment,
          viewModel: viewModel,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Modificar cita'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Cancelar cita'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Cancelar solicitud recurrente'), findsNothing);
    await tester.tap(find.text('Cancelar cita'));
    await tester.pumpAndSettle();
    expect(find.text('¿Cancelar esta sesión?'), findsOneWidget);
    viewModel.dispose();
  });

  testWidgets('live appointment updates pending recurring to approved', (
    tester,
  ) async {
    final pending = _appointment(
      status: AppointmentStatus.pending,
      date: _madridTomorrow(),
      recurrenceSeriesId: 'series-1',
      recurrenceIndex: 0,
    );
    final approved = _appointment(
      status: AppointmentStatus.approved,
      date: pending.preferredSlots.first.date,
      recurrenceSeriesId: 'series-1',
      recurrenceIndex: 0,
    );
    final repository = FakePortalRepository(appointments: [pending]);
    final viewModel = ClientPortalViewModel(repository: repository, uid: 'uid')
      ..start();

    await tester.pumpWidget(
      MaterialApp(
        home: AppointmentDetailScreen(
          appointment: pending,
          viewModel: viewModel,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Cancelar solicitud recurrente'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Cancelar solicitud recurrente'), findsOneWidget);

    repository.emitAppointments([approved]);
    await tester.pumpAndSettle();

    expect(find.text('Cancelar solicitud recurrente'), findsNothing);
    expect(find.text('Cancelar cita'), findsOneWidget);
    expect(find.text('Modificar cita'), findsNothing);
    viewModel.dispose();
  });

  testWidgets('recurring detail works without the series document yet', (
    tester,
  ) async {
    final appointment = _appointment(
      status: AppointmentStatus.pending,
      date: _madridTomorrow(),
      recurrenceSeriesId: 'series-1',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AppointmentDetailScreen(
          appointment: appointment,
          viewModel: ClientPortalViewModel(
            repository: FakePortalRepository(),
            uid: 'uid',
          ),
        ),
      ),
    );

    expect(find.text('Entrenamiento recurrente'), findsOneWidget);
    expect(find.text('3 días'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('pending recurring can be cancelled with a spent bono', (
    tester,
  ) async {
    final appointment = _appointment(
      status: AppointmentStatus.pending,
      date: _madridTomorrow(),
      recurrenceSeriesId: 'series-1',
    );
    final repository = FakePortalRepository(
      appointments: [appointment],
      bonos: [_bono(status: BonoStatus.agotado)],
    );
    final viewModel = ClientPortalViewModel(repository: repository, uid: 'uid')
      ..start();

    await tester.pumpWidget(
      MaterialApp(
        home: AppointmentDetailScreen(
          appointment: appointment,
          viewModel: viewModel,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Cancelar solicitud recurrente'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Cancelar solicitud recurrente'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Cancelar solicitud'));
    await tester.pumpAndSettle();
    expect(repository.cancelledSeriesIds, ['series-1']);
    viewModel.dispose();
  });

  testWidgets(
    'simple appointment today hides actions and shows same-day warning',
    (tester) async {
      final now = DateTime.utc(2026, 9, 2, 10);
      final appointment = _appointment(
        status: AppointmentStatus.pending,
        date: getMadridDateKey(now),
        time: '23:00',
      );
      final viewModel = ClientPortalViewModel(
        repository: FakePortalRepository(appointments: [appointment]),
        uid: 'uid',
        now: () => now,
      )..start();

      await tester.pumpWidget(
        MaterialApp(
          home: AppointmentDetailScreen(
            appointment: appointment,
            viewModel: viewModel,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(sameDayChangeNotAllowedMessage),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text(sameDayChangeNotAllowedMessage), findsOneWidget);
      expect(find.text('Modificar cita'), findsNothing);
      expect(find.text('Cancelar cita'), findsNothing);
      viewModel.dispose();
    },
  );

  testWidgets(
    'same-day warning stays visible after the appointment hour has passed',
    (tester) async {
      final now = DateTime.utc(2026, 9, 2, 12);
      final appointment = _appointment(
        status: AppointmentStatus.approved,
        date: getMadridDateKey(now),
        time: '09:00',
      );
      final viewModel = ClientPortalViewModel(
        repository: FakePortalRepository(appointments: [appointment]),
        uid: 'uid',
        now: () => now,
      )..start();

      await tester.pumpWidget(
        MaterialApp(
          home: AppointmentDetailScreen(
            appointment: appointment,
            viewModel: viewModel,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(sameDayChangeNotAllowedMessage),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text(sameDayChangeNotAllowedMessage), findsOneWidget);
      expect(find.text('Modificar cita'), findsNothing);
      expect(find.text('Cancelar cita'), findsNothing);
      viewModel.dispose();
    },
  );

  testWidgets('simple appointment tomorrow keeps current actions', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 9, 2, 10);
    final appointment = _appointment(
      status: AppointmentStatus.pending,
      date: _madridTomorrow(now),
      time: '23:00',
    );
    final viewModel = ClientPortalViewModel(
      repository: FakePortalRepository(appointments: [appointment]),
      uid: 'uid',
      now: () => now,
    )..start();

    await tester.pumpWidget(
      MaterialApp(
        home: AppointmentDetailScreen(
          appointment: appointment,
          viewModel: viewModel,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Modificar cita'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text(sameDayChangeNotAllowedMessage), findsNothing);
    expect(find.text('Modificar cita'), findsOneWidget);
    expect(find.text('Cancelar cita'), findsOneWidget);
    viewModel.dispose();
  });

  testWidgets(
    'approved recurring occurrence today hides cancel and shows warning',
    (tester) async {
      final now = DateTime.utc(2026, 9, 2, 10);
      final appointment = _appointment(
        status: AppointmentStatus.approved,
        date: getMadridDateKey(now),
        time: '23:00',
        recurrenceSeriesId: 'series-1',
      );
      final viewModel = ClientPortalViewModel(
        repository: FakePortalRepository(appointments: [appointment]),
        uid: 'uid',
        now: () => now,
      )..start();

      await tester.pumpWidget(
        MaterialApp(
          home: AppointmentDetailScreen(
            appointment: appointment,
            viewModel: viewModel,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(sameDayChangeNotAllowedMessage),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text(sameDayChangeNotAllowedMessage), findsOneWidget);
      expect(find.text('Cancelar cita'), findsNothing);
      expect(find.text('Modificar cita'), findsNothing);
      viewModel.dispose();
    },
  );

  testWidgets(
    'pending series with a sibling today hides series cancel on a later occurrence',
    (tester) async {
      final now = DateTime.utc(2026, 9, 2, 10);
      final selected = _appointment(
        id: 'later',
        status: AppointmentStatus.pending,
        date: _madridTomorrow(now),
        time: '23:00',
        recurrenceSeriesId: 'series-1',
      );
      final siblingToday = _appointment(
        id: 'today',
        status: AppointmentStatus.pending,
        date: getMadridDateKey(now),
        time: '09:00',
        recurrenceSeriesId: 'series-1',
      );
      final viewModel = ClientPortalViewModel(
        repository: FakePortalRepository(
          appointments: [selected, siblingToday],
          recurringSeries: [_series()],
        ),
        uid: 'uid',
        now: () => now,
      )..start();

      await tester.pumpWidget(
        MaterialApp(
          home: AppointmentDetailScreen(
            appointment: selected,
            viewModel: viewModel,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(pendingSeriesHasOccurrenceTodayMessage),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text(pendingSeriesHasOccurrenceTodayMessage), findsOneWidget);
      expect(find.text('Cancelar solicitud recurrente'), findsNothing);
      expect(find.text(sameDayChangeNotAllowedMessage), findsNothing);
      viewModel.dispose();
    },
  );

  testWidgets(
    'pending series with only future occurrences keeps series cancel',
    (tester) async {
      final now = DateTime.utc(2026, 9, 2, 10);
      final appointment = _appointment(
        status: AppointmentStatus.pending,
        date: _madridTomorrow(now),
        time: '23:00',
        recurrenceSeriesId: 'series-1',
      );
      final viewModel = ClientPortalViewModel(
        repository: FakePortalRepository(
          appointments: [appointment],
          recurringSeries: [_series()],
        ),
        uid: 'uid',
        now: () => now,
      )..start();

      await tester.pumpWidget(
        MaterialApp(
          home: AppointmentDetailScreen(
            appointment: appointment,
            viewModel: viewModel,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Cancelar solicitud recurrente'),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text(pendingSeriesHasOccurrenceTodayMessage), findsNothing);
      expect(find.text('Cancelar solicitud recurrente'), findsOneWidget);
      viewModel.dispose();
    },
  );

  testWidgets(
    'editing a same-day appointment shows a warning and disables save',
    (tester) async {
      final now = DateTime.utc(2026, 9, 2, 8);
      final appointment = _appointment(
        status: AppointmentStatus.pending,
        date: getMadridDateKey(now),
        time: '23:00',
      );
      final repository = FakePortalRepository(
        appointments: [appointment],
        siteConfig: const SiteConfig(
          startHour: 8,
          endHour: 24,
          slotInterval: 30,
          bonoExpirationMonths: 1,
          maintenanceMode: false,
        ),
      );
      final viewModel = ClientPortalViewModel(
        repository: repository,
        uid: 'uid',
        now: () => now,
      )..start();

      await tester.pumpWidget(
        MaterialApp(
          home: BookingScreen(
            viewModel: viewModel,
            editingAppointment: appointment,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(sameDayChangeNotAllowedMessage), findsOneWidget);
      await _bookingContinueUntil(tester, find.text('Guardar cambios'));
      expect(find.text('Guardar cambios'), findsOneWidget);
      expect(
        tester
            .widget<FocusPrimaryButton>(
              find.widgetWithText(FocusPrimaryButton, 'Guardar cambios'),
            )
            .onPressed,
        isNull,
      );
      viewModel.dispose();
    },
  );

  testWidgets(
    'detail hides actions after the Madrid midnight boundary without recreating the view model',
    (tester) async {
      var now = DateTime.utc(2026, 9, 1, 21, 30);
      final appointment = _appointment(
        status: AppointmentStatus.pending,
        date: _madridTomorrow(now),
        time: '23:00',
      );
      final timers = <_UiTestTimer>[];
      final viewModel = ClientPortalViewModel(
        repository: FakePortalRepository(appointments: [appointment]),
        uid: 'uid',
        now: () => now,
        appointmentTimerFactory: (duration, callback) {
          final timer = _UiTestTimer(duration, callback);
          timers.add(timer);
          return timer;
        },
      )..start();

      await tester.pumpWidget(
        MaterialApp(
          home: AppointmentDetailScreen(
            appointment: appointment,
            viewModel: viewModel,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Modificar cita'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Modificar cita'), findsOneWidget);
      expect(find.text('Cancelar cita'), findsOneWidget);

      now = nextMadridMidnightUtc(now);
      final timer = timers.lastWhere((item) => item.isActive);
      timer.fire();
      await tester.pump();

      expect(find.text('Modificar cita'), findsNothing);
      expect(find.text('Cancelar cita'), findsNothing);
      expect(find.text(sameDayChangeNotAllowedMessage), findsOneWidget);
      viewModel.dispose();
    },
  );
}

class _LargeTextHarness extends StatelessWidget {
  const _LargeTextHarness({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppTextSizeScope(
      textSize: AppTextSize.large,
      onChanged: (_) {},
      child: MaterialApp(
        builder: (context, appChild) => AppTextSizing.applyGlobally(
          context,
          child: appChild ?? const SizedBox.shrink(),
        ),
        home: child,
      ),
    );
  }
}

Bono _bono({BonoStatus status = BonoStatus.activo}) {
  return Bono(
    id: 'bono-id',
    userId: 'uid',
    tamano: 240,
    minutosTotales: 240,
    minutosRestantes: 240,
    fechaAsignacion: '2030-05-01',
    fechaExpiracion: '2030-06-01',
    estado: status,
    historial: const [],
    asignadoPor: 'admin',
    createdAt: '2030-05-01T10:00:00.000Z',
  );
}

Appointment _appointment({
  required AppointmentStatus status,
  required String date,
  String id = 'appointment-id',
  String time = '10:00',
  String createdAt = '2030-05-01T10:00:00.000Z',
  String? recurrenceSeriesId,
  int? recurrenceIndex,
  String? assignedTrainer,
}) {
  return Appointment(
    id: id,
    userId: 'uid',
    name: 'Cliente',
    email: 'cliente@example.com',
    phone: '+34612345678',
    serviceType: 'Bono Mensual de Entrenamiento',
    durationMinutes: 45,
    preferredSlots: [TimeSlot(date: date, time: time)],
    reason: '',
    status: status,
    createdAt: createdAt,
    recurrenceSeriesId: recurrenceSeriesId,
    recurrenceIndex: recurrenceIndex,
    assignedTrainer: assignedTrainer,
  );
}

Bono _bonoWithMinutes(int remaining) {
  return Bono(
    id: 'bono-id',
    userId: 'uid',
    tamano: 240,
    minutosTotales: 240,
    minutosRestantes: remaining,
    fechaAsignacion: '2026-09-01',
    fechaExpiracion: '2026-10-31',
    estado: BonoStatus.activo,
    historial: const [],
    asignadoPor: 'admin',
    createdAt: '2026-09-01T10:00:00.000Z',
  );
}

RecurringAppointmentSeries _series({String id = 'series-1'}) {
  return RecurringAppointmentSeries(
    id: id,
    userId: 'uid',
    serviceType: 'Bono Mensual de Entrenamiento',
    durationMinutes: 60,
    startDate: '2026-09-10',
    startTime: '18:00',
    intervalDays: 3,
    endDate: '2026-09-19',
    occurrenceCount: 4,
    totalMinutes: 240,
    bonoId: 'bono-id',
    status: AppointmentStatus.pending,
    origin: RecurringSeriesOrigin.client,
    createdAt: '2026-09-01T10:00:00.000Z',
  );
}

FakePortalRepository _bookingRepository({
  Bono? bono,
  List<BlockedSlot> blockedSlots = const [],
  List<SlotOccupancy> slotOccupancy = const [],
  List<Appointment> appointments = const [],
  Completer<void>? availabilityGate,
  Object? availabilityFailure,
}) {
  return FakePortalRepository(
    bonos: [bono ?? _bonoWithMinutes(240)],
    blockedSlots: blockedSlots,
    slotOccupancy: slotOccupancy,
    appointments: appointments,
    availabilityGate: availabilityGate,
    availabilityFailure: availabilityFailure,
    siteConfig: const SiteConfig(
      startHour: 8,
      endHour: 20,
      slotInterval: 30,
      bonoExpirationMonths: 1,
      maintenanceMode: false,
    ),
  );
}

ClientPortalViewModel _bookingViewModel({
  FakePortalRepository? repository,
  DateTime? now,
}) {
  return ClientPortalViewModel(
    repository: repository ?? _bookingRepository(),
    uid: 'uid',
    now: () => now ?? DateTime(2026, 9, 10, 9),
  )..start();
}

String _madridTomorrow([DateTime? now]) {
  final today = getMadridDateKey(now ?? DateTime.now());
  final parts = today.split('-');
  final next = DateTime.utc(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  ).add(const Duration(days: 1));
  final month = next.month.toString().padLeft(2, '0');
  final day = next.day.toString().padLeft(2, '0');
  return '${next.year}-$month-$day';
}

String _wireDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

Future<void> _bookingContinueUntil(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 8; i++) {
    await tester.pumpAndSettle();
    if (_finderHasMatch(finder)) return;
    final next = find.widgetWithText(FilledButton, 'Continuar');
    if (next.evaluate().isEmpty) return;
    if (tester.widget<FilledButton>(next).onPressed == null) return;
    await tester.ensureVisible(next);
    await tester.tap(next);
  }
}

Future<void> _bookingSelectSlot(
  WidgetTester tester, {
  required String dateLabel,
  String time = '18:00',
}) async {
  await _bookingContinueUntil(tester, find.text(dateLabel));
  await tester.tap(find.text(dateLabel));
  await tester.pumpAndSettle();
  await tester.tap(find.text(time).first);
  await tester.pumpAndSettle();
}

bool _finderHasMatch(Finder finder) {
  try {
    return finder.evaluate().isNotEmpty;
  } on StateError {
    return false;
  }
}

Future<void> _selectRecurringHasta(WidgetTester tester, String endDate) async {
  await tester.tap(find.byKey(const Key('recurring-end-date')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key('recurring-hasta-option-$endDate')));
  await tester.pumpAndSettle();
}

class _UiTestTimer implements Timer {
  _UiTestTimer(this.duration, this._callback);

  final Duration duration;
  final void Function() _callback;
  bool _isActive = true;

  void fire() {
    if (!_isActive) return;
    _isActive = false;
    _callback();
  }

  @override
  void cancel() => _isActive = false;

  @override
  bool get isActive => _isActive;

  @override
  int get tick => _isActive ? 0 : 1;
}
