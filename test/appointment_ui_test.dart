import 'package:app_focus_club/features/client/application/client_portal_view_model.dart';
import 'package:app_focus_club/features/client/data/portal_repository.dart';
import 'package:app_focus_club/features/client/domain/portal_models.dart';
import 'package:app_focus_club/features/client/presentation/appointment_detail_screen.dart';
import 'package:app_focus_club/features/client/presentation/booking_screen.dart';
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
    await tester.scrollUntilVisible(
      find.text('Modificar cita'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Modificar cita'), findsOneWidget);
    expect(find.text('Cancelar cita'), findsOneWidget);
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

Bono _bono() {
  return const Bono(
    id: 'bono-id',
    userId: 'uid',
    tamano: 240,
    minutosTotales: 240,
    minutosRestantes: 240,
    fechaAsignacion: '2030-05-01',
    fechaExpiracion: '2030-06-01',
    estado: BonoStatus.activo,
    historial: [],
    asignadoPor: 'admin',
    createdAt: '2030-05-01T10:00:00.000Z',
  );
}

Appointment _appointment({
  required AppointmentStatus status,
  required String date,
}) {
  return Appointment(
    id: 'appointment-id',
    userId: 'uid',
    name: 'Cliente',
    email: 'cliente@example.com',
    phone: '+34612345678',
    serviceType: 'Bono Mensual de Entrenamiento',
    durationMinutes: 45,
    preferredSlots: [TimeSlot(date: date, time: '10:00')],
    reason: '',
    status: status,
    createdAt: '2030-05-01T10:00:00.000Z',
  );
}

String _wireDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}
