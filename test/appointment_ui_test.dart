import 'package:app_focus_club/features/client/application/client_portal_view_model.dart';
import 'package:app_focus_club/features/client/data/portal_repository.dart';
import 'package:app_focus_club/features/client/domain/portal_models.dart';
import 'package:app_focus_club/features/client/presentation/appointment_detail_screen.dart';
import 'package:app_focus_club/features/client/presentation/booking_screen.dart';
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

  testWidgets('past and cancelled appointments do not expose appointment actions', (
    tester,
  ) async {
    final repository = FakePortalRepository();
    final viewModel = ClientPortalViewModel(repository: repository, uid: 'uid');
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
  });

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
    await tester.tap(find.widgetWithText(FilledButton, 'Cancelar cita'));
    await tester.pumpAndSettle();

    expect(repository.cancelledAppointmentIds, [appointment.id]);
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
