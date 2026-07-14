import 'package:app_focus_club/features/client/application/client_portal_view_model.dart';
import 'package:app_focus_club/features/client/data/portal_repository.dart';
import 'package:app_focus_club/features/client/domain/portal_availability.dart';
import 'package:app_focus_club/features/client/domain/portal_models.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('appointment compatibility', () {
    test('parses cancelled status', () {
      expect(AppointmentStatus.fromWire('cancelled').name, 'cancelled');
    });

    test('uses legacy date and time when no current slot exists', () {
      final appointment = Appointment.fromMap('legacy-id', {
        'userId': 'uid',
        'name': 'Cliente',
        'email': 'cliente@example.com',
        'phone': '+34612345678',
        'serviceType': 'Bono Mensual de Entrenamiento',
        'duration': '45',
        'preferredSlots': const [],
        'reason': '',
        'status': 'pending',
        'date': '2030-05-20',
        'time': '10:30',
        'createdAt': '2030-05-01T10:00:00.000Z',
      });

      expect(appointment.schedulingSlot, const TimeSlot(date: '2030-05-20', time: '10:30'));
    });
  });

  test('active appointments exclude past and invalid appointments', () {
    final now = DateTime.now();
    final state = ClientPortalState(
      appointments: [
        _appointment(
          id: 'future',
          date: _wireDate(now.add(const Duration(days: 1))),
          time: '10:00',
        ),
        _appointment(
          id: 'past',
          date: _wireDate(now.subtract(const Duration(days: 1))),
          time: '10:00',
        ),
        _appointment(id: 'invalid', date: 'invalid', time: '10:00'),
      ],
    );

    expect(state.activeAppointments.map((item) => item.id), ['future']);
  });

  test('history contains rejected, cancelled, past and invalid appointments', () {
    final now = DateTime.now();
    final state = ClientPortalState(
      appointments: [
        _appointment(
          id: 'future',
          date: _wireDate(now.add(const Duration(days: 1))),
          time: '10:00',
        ),
        _appointment(
          id: 'past',
          date: _wireDate(now.subtract(const Duration(days: 1))),
          time: '10:00',
        ),
        _appointment(
          id: 'rejected',
          date: _wireDate(now.add(const Duration(days: 1))),
          time: '11:00',
          status: AppointmentStatus.rejected,
        ),
        _appointment(
          id: 'cancelled',
          date: _wireDate(now.add(const Duration(days: 1))),
          time: '12:00',
          status: AppointmentStatus.cancelled,
        ),
        _appointment(id: 'invalid', date: 'invalid', time: '10:00'),
      ],
    );

    expect(
      state.historyAppointments.map((item) => item.id),
      ['past', 'rejected', 'cancelled', 'invalid'],
    );
  });

  test('availability ignores the appointment being edited', () {
    const appointment = Appointment(
      id: 'editing',
      userId: 'uid',
      name: 'Cliente',
      email: 'cliente@example.com',
      phone: '+34612345678',
      serviceType: 'Bono Mensual de Entrenamiento',
      durationMinutes: 45,
      preferredSlots: [TimeSlot(date: '2030-05-20', time: '10:00')],
      reason: '',
      status: AppointmentStatus.pending,
      createdAt: '2030-05-01T10:00:00.000Z',
    );

    expect(
      overlapsActiveAppointment(
        start: const TimeSlot(date: '2030-05-20', time: '10:00'),
        durationMinutes: 45,
        appointments: const [appointment],
        excludedAppointmentId: appointment.id,
      ),
      isFalse,
    );
  });

  test('fake portal records cancellation and slot updates', () async {
    final repository = FakePortalRepository();

    await repository.cancelOwnAppointment('appointment-id');
    await repository.updateOwnAppointmentSlot(
      appointmentId: 'appointment-id',
      preferredSlot: const TimeSlot(date: '2030-05-20', time: '10:00'),
    );

    expect(repository.cancelledAppointmentIds, ['appointment-id']);
    expect(repository.slotUpdates.single.appointmentId, 'appointment-id');
    expect(repository.slotUpdates.single.preferredSlot.time, '10:00');
  });

  test('maps appointment mutation errors to friendly Spanish messages', () {
    expect(
      appointmentMutationErrorMessage(
        _FakeFunctionsException(code: 'permission-denied', message: 'Denied'),
      ),
      'No tienes permisos para modificar esta cita.',
    );
    expect(
      appointmentMutationErrorMessage(
        _FakeFunctionsException(
          code: 'failed-precondition',
          message: 'Slot is blocked.',
        ),
      ),
      'Esta franja ya no está disponible.',
    );
  });
}

class _FakeFunctionsException extends FirebaseFunctionsException {
  _FakeFunctionsException({required super.code, required super.message});
}

Appointment _appointment({
  required String id,
  required String date,
  required String time,
  AppointmentStatus status = AppointmentStatus.pending,
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
    createdAt: '2030-05-01T10:00:00.000Z',
  );
}

String _wireDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}
