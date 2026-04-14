import 'package:app_focus_club/features/client/domain/portal_availability.dart';
import 'package:app_focus_club/features/client/domain/portal_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('internal slot expansion', () {
    test('30 minutes expands to two 15 minute sub-slots', () {
      final slots = expandInternalSlots(
        const TimeSlot(date: '2026-04-30', time: '19:30'),
        30,
      );

      expect(slots.map((slot) => slot.time), ['19:30', '19:45']);
    });

    test('45 minutes expands to three 15 minute sub-slots', () {
      final slots = expandInternalSlots(
        const TimeSlot(date: '2026-04-30', time: '19:30'),
        45,
      );

      expect(slots.map((slot) => slot.time), ['19:30', '19:45', '20:00']);
    });

    test('60 minutes expands to four 15 minute sub-slots', () {
      final slots = expandInternalSlots(
        const TimeSlot(date: '2026-04-30', time: '19:30'),
        60,
      );

      expect(slots.map((slot) => slot.time), [
        '19:30',
        '19:45',
        '20:00',
        '20:15',
      ]);
    });
  });

  group('availability', () {
    test(
      'duration is full when any internal sub-slot reaches capacity two',
      () {
        final isFull = isDurationFull(
          start: const TimeSlot(date: '2026-04-30', time: '19:30'),
          durationMinutes: 45,
          occupancy: const [
            SlotOccupancy(
              id: '2026-04-30_20:00',
              date: '2026-04-30',
              time: '20:00',
              count: maxCapacityPerInternalSlot,
            ),
          ],
        );

        expect(isFull, isTrue);
      },
    );

    test('duration is blocked when any internal sub-slot is blocked', () {
      final isBlocked = isDurationBlocked(
        start: const TimeSlot(date: '2026-04-30', time: '19:30'),
        durationMinutes: 60,
        blockedSlots: const [
          BlockedSlot(id: 'blocked', date: '2026-04-30', time: '20:15'),
        ],
      );

      expect(isBlocked, isTrue);
    });

    test('detects overlap with existing active appointment', () {
      final hasOverlap = overlapsActiveAppointment(
        start: const TimeSlot(date: '2026-04-30', time: '19:45'),
        durationMinutes: 30,
        appointments: const [
          Appointment(
            id: 'appointment',
            userId: 'uid',
            name: 'Cliente',
            email: 'cliente@example.com',
            phone: '+34612345678',
            serviceType: 'Bono Mensual de Entrenamiento',
            durationMinutes: 60,
            preferredSlots: [TimeSlot(date: '2026-04-30', time: '19:30')],
            reason: '',
            status: AppointmentStatus.pending,
            createdAt: '2026-04-13T10:00:00.000Z',
          ),
        ],
      );

      expect(hasOverlap, isTrue);
    });
  });

  group('active bono selection', () {
    test('returns null when there is no active bono', () {
      expect(selectUniqueActiveBono(const []), isNull);
    });

    test('returns the single active bono', () {
      final bono = _bono(id: 'active', estado: BonoStatus.activo);

      expect(selectUniqueActiveBono([bono]), same(bono));
    });

    test('throws when more than one active bono exists', () {
      expect(
        () => selectUniqueActiveBono([
          _bono(id: 'active-1', estado: BonoStatus.activo),
          _bono(id: 'active-2', estado: BonoStatus.activo),
        ]),
        throwsA(isA<ActiveBonoConsistencyException>()),
      );
    });
  });

  group('model parsing', () {
    test('appointment accepts optional parity fields as absent', () {
      final appointment = Appointment.fromMap('id', {
        'userId': 'uid',
        'name': 'Cliente',
        'email': 'cliente@example.com',
        'phone': '+34612345678',
        'serviceType': 'Bono Mensual de Entrenamiento',
        'duration': '60',
        'preferredSlots': [
          {'date': '2026-04-30', 'time': '19:30'},
        ],
        'reason': '',
        'status': 'approved',
        'approvedSlot': {'date': '2026-04-30', 'time': '19:30'},
        'createdAt': '2026-04-13T10:00:00.000Z',
      });

      expect(appointment.trainerNotes, isNull);
      expect(appointment.assignedTrainer, isNull);
      expect(appointment.durationMinutes, 60);
      expect(appointment.approvedSlot?.key, '2026-04-30_19:30');
    });

    test('site config accepts observed logo fields', () {
      final config = SiteConfig.fromMap({
        'startHour': 8,
        'endHour': 20,
        'slotInterval': 30,
        'bonoExpirationMonths': 1,
        'maintenanceMode': false,
        'sessionDuration': 60,
        'logoUrl': 'https://example.com/logo.png',
        'logoStoragePath': 'site/logo.png',
        'updatedAt': '2026-04-13T10:00:00.000Z',
      });

      expect(config.sessionDuration, 60);
      expect(config.logoUrl, isNotNull);
      expect(config.logoStoragePath, isNotNull);
    });
  });
}

Bono _bono({required String id, required BonoStatus estado}) {
  return Bono(
    id: id,
    userId: 'uid',
    tamano: 360,
    minutosTotales: 360,
    minutosRestantes: 120,
    fechaAsignacion: '2026-04-01T00:00:00.000Z',
    fechaExpiracion: '2026-05-01T00:00:00.000Z',
    estado: estado,
    historial: const [],
    asignadoPor: 'admin@example.com',
    createdAt: '2026-04-01T00:00:00.000Z',
  );
}
