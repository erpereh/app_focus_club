import 'package:app_focus_club/features/client/application/client_portal_view_model.dart';
import 'package:app_focus_club/features/client/data/portal_repository.dart';
import 'package:app_focus_club/features/client/domain/portal_models.dart';
import 'package:app_focus_club/features/client/presentation/appointment_detail_screen.dart';
import 'package:app_focus_club/features/client/presentation/appointments_screen.dart';
import 'package:app_focus_club/features/client/presentation/booking_screen.dart';
import 'package:app_focus_club/features/client/presentation/dashboard_screen.dart';
import 'package:app_focus_club/features/client/widgets/appointment_display.dart';
import 'package:app_focus_club/features/client/widgets/client_cards.dart';
import 'package:app_focus_club/shared/widgets/focus_empty_state.dart';
import 'package:app_focus_club/shared/widgets/focus_glass_card.dart';
import 'package:app_focus_club/theme/app_text_size.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('future pending appointment exposes modify and cancel actions', (
    tester,
  ) async {
    final repository = FakePortalRepository();
    final viewModel = ClientPortalViewModel(repository: repository, uid: 'uid');
    final appointment = _appointment(
      status: AppointmentStatus.pending,
      date: _wireDate(DateTime.now().add(const Duration(days: 1))),
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
      find.text('Modificar cita'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Modificar cita'), findsOneWidget);

    now = DateTime(2030, 5, 20, 10);
    viewModel.refreshTemporalState();
    await tester.pump();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 1000));
    await tester.pumpAndSettle();

    expect(find.text('Realizada'), findsOneWidget);
    expect(find.text('Esta cita ya se ha realizado.'), findsOneWidget);
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
      date: _wireDate(DateTime.now().add(const Duration(days: 1))),
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
      matching: find.byType(FocusGlassCard),
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
          body: DashboardScreen(
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
            onOpenAppointments: () {},
            onOpenProfile: () {},
            onOpenBooking: () {},
          ),
        ),
      ),
    );
    await tester.scrollUntilVisible(find.text('Historial Citas'), 500);
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();

    final latestSchedule =
        '${latest.dateLabel} - ${latest.timeLabel} - ${latest.durationMinutes} min';
    final secondSchedule =
        '${second.dateLabel} - ${second.timeLabel} - ${second.durationMinutes} min';
    expect(find.text(latestSchedule), findsOneWidget);
    expect(find.text(secondSchedule), findsOneWidget);
    expect(
      find.text(
        '${older.dateLabel} - ${older.timeLabel} - ${older.durationMinutes} min',
      ),
      findsNothing,
    );
    expect(
      find.text(
        '${futureCancelled.dateLabel} - ${futureCancelled.timeLabel} - ${futureCancelled.durationMinutes} min',
      ),
      findsNothing,
    );
    expect(
      find.text(
        '${futureRejected.dateLabel} - ${futureRejected.timeLabel} - ${futureRejected.durationMinutes} min',
      ),
      findsNothing,
    );
    expect(
      tester.getTopLeft(find.text(latestSchedule)).dy,
      lessThan(tester.getTopLeft(find.text(secondSchedule)).dy),
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
      date: _wireDate(DateTime.now().add(const Duration(days: 1))),
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
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();

    final gridFinder = find.byKey(const Key('booking-slot-grid'));
    expect(gridFinder, findsOneWidget);
    final grid = tester.widget<GridView>(gridFinder);
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 3);
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
      date: _wireDate(DateTime.now().add(const Duration(days: 1))),
    );

    await tester.pumpWidget(
      _LargeTextHarness(
        child: AppointmentDetailScreen(
          appointment: appointment,
          viewModel: viewModel,
        ),
      ),
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
      date: _wireDate(DateTime.now().add(const Duration(days: 1))),
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
  );
}

String _wireDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}
