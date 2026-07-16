import 'package:app_focus_club/features/client/application/client_portal_view_model.dart';
import 'package:app_focus_club/features/client/data/portal_repository.dart';
import 'package:app_focus_club/features/client/domain/portal_availability.dart';
import 'package:app_focus_club/features/client/domain/portal_models.dart';
import 'package:app_focus_club/features/client/widgets/appointment_display.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('human friendly minute formatting', () {
    test('formats minutes as compact hours and minutes', () {
      expect(formatMinutesDuration(0), '0min');
      expect(formatMinutesDuration(30), '30min');
      expect(formatMinutesDuration(60), '1h');
      expect(formatMinutesDuration(90), '1h 30min');
      expect(formatMinutesDuration(150), '2h 30min');
      expect(formatMinutesDuration(240), '4h');
    });

    test('bono labels use the real total and remaining minutes', () {
      final fourHourBono = _bono(total: 240, remaining: 150);
      final eightHourBono = _bono(total: 480, remaining: 300);

      expect(fourHourBono.nameLabel, 'Bono Mensual de Entrenamiento 4h');
      expect(fourHourBono.availableTimeLabel, '2h 30min disponibles');
      expect(fourHourBono.minutesLabel, '1h 30min de 4h usados');
      expect(eightHourBono.nameLabel, 'Bono Mensual de Entrenamiento 8h');
      expect(eightHourBono.availableTimeLabel, '5h disponibles');
      expect(eightHourBono.minutesLabel, '3h de 8h usados');
    });

    test('bono package size wins over an inconsistent legacy total', () {
      final bono = _bono(total: 480, remaining: 150, size: 240);

      expect(bono.displayTotalMinutes, 240);
      expect(bono.nameLabel, 'Bono Mensual de Entrenamiento 4h');
      expect(bono.availableTimeLabel, '2h 30min disponibles');
      expect(bono.minutesLabel, '1h 30min de 4h usados');
      expect(bono.usedMinutes, 90);
    });
  });

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

      expect(
        appointment.schedulingSlot,
        const TimeSlot(date: '2030-05-20', time: '10:30'),
      );
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

  test('appointment moves from upcoming to history when its time passes', () {
    final state = ClientPortalState(
      appointments: [
        _appointment(id: 'current', date: '2030-05-20', time: '10:00'),
      ],
    );

    expect(
      state.activeAppointmentsAt(DateTime(2030, 5, 20, 9, 59)).single.id,
      'current',
    );
    expect(
      state.historyAppointmentsAt(DateTime(2030, 5, 20, 9, 59)),
      isEmpty,
    );
    expect(
      state.activeAppointmentsAt(DateTime(2030, 5, 20, 10, 1)),
      isEmpty,
    );
    expect(
      state.historyAppointmentsAt(DateTime(2030, 5, 20, 10, 1)).single.id,
      'current',
    );
  });

  test('dashboard advances to the next appointment after the first passes', () {
    final state = ClientPortalState(
      appointments: [
        _appointment(id: 'first', date: '2030-05-20', time: '10:00'),
        _appointment(id: 'second', date: '2030-05-20', time: '11:00'),
      ],
    );

    expect(
      state.dashboardAppointmentsAt(DateTime(2030, 5, 20, 9, 30)).first.id,
      'first',
    );
    expect(
      state.dashboardAppointmentsAt(DateTime(2030, 5, 20, 10, 30)).first.id,
      'second',
    );
  });

  test('past appointments expose a derived completed or missed label', () {
    final approved = _appointment(
      id: 'approved',
      date: '2030-05-20',
      time: '10:00',
      status: AppointmentStatus.approved,
    );
    final pending = _appointment(
      id: 'pending',
      date: '2030-05-20',
      time: '10:00',
    );
    final now = DateTime(2030, 5, 20, 10, 1);

    expect(appointmentDisplayStatusLabel(approved, now: now), 'Realizada');
    expect(appointmentDisplayStatusLabel(pending, now: now), 'No realizada');
    expect(approved.status, AppointmentStatus.approved);
    expect(pending.status, AppointmentStatus.pending);
  });

  test('dashboard appointments are sorted and limited to the nearest two', () {
    final now = DateTime.now();
    final state = ClientPortalState(
      appointments: [
        _appointment(
          id: 'third',
          date: _wireDate(now.add(const Duration(days: 3))),
          time: '10:00',
        ),
        _appointment(
          id: 'first',
          date: _wireDate(now.add(const Duration(days: 1))),
          time: '09:00',
        ),
        _appointment(
          id: 'cancelled',
          date: _wireDate(now.add(const Duration(days: 1))),
          time: '08:00',
          status: AppointmentStatus.cancelled,
        ),
        _appointment(
          id: 'second',
          date: _wireDate(now.add(const Duration(days: 2))),
          time: '11:00',
        ),
      ],
    );

    expect(state.dashboardAppointments.map((appointment) => appointment.id), [
      'first',
      'second',
    ]);
  });

  test(
    'history contains rejected, cancelled, past and invalid appointments',
    () {
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

      expect(state.historyAppointments.map((item) => item.id), [
        'cancelled',
        'rejected',
        'past',
        'invalid',
      ]);
    },
  );

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

Bono _bono({
  required int total,
  required int remaining,
  int? size,
}) {
  return Bono(
    id: 'bono-$total',
    userId: 'uid',
    tamano: size ?? total,
    minutosTotales: total,
    minutosRestantes: remaining,
    fechaAsignacion: '2030-05-01',
    fechaExpiracion: '2030-06-01',
    estado: BonoStatus.activo,
    historial: const [],
    asignadoPor: 'admin',
    createdAt: '2030-05-01T10:00:00.000Z',
  );
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
