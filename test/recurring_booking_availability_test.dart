import 'package:app_focus_club/features/client/domain/portal_models.dart';
import 'package:app_focus_club/features/client/domain/recurring_booking.dart';
import 'package:app_focus_club/features/client/domain/recurring_booking_availability.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const siteConfig = SiteConfig(
    startHour: 8,
    endHour: 20,
    slotInterval: 30,
    bonoExpirationMonths: 1,
    maintenanceMode: false,
    maxCapacity: 5,
  );
  final now = DateTime(2026, 9, 20, 8);
  final options = getRecurringEndDateOptions(
    startDate: '2026-09-23',
    intervalDays: 2,
    durationMinutes: 60,
    remainingMinutes: 240,
  );

  List<RecurringHastaOptionStatus> evaluate({
    Map<String, int> occupancy = const {},
    Set<String> blockedKeys = const {},
    List<Appointment> appointments = const [],
    String startTime = '11:00',
    int durationMinutes = 60,
    DateTime? clock,
    SiteConfig config = siteConfig,
  }) {
    return evaluateRecurringHastaOptions(
      startDate: '2026-09-23',
      startTime: startTime,
      intervalDays: 2,
      durationMinutes: durationMinutes,
      options: options,
      occupancy: occupancy,
      blockedKeys: blockedKeys,
      appointments: appointments,
      siteConfig: config,
      now: clock ?? now,
    );
  }

  test('base options are 25, 27 and 29', () {
    expect(options.map((option) => option.endDate), [
      '2026-09-25',
      '2026-09-27',
      '2026-09-29',
    ]);
  });

  test('marks later options blocked when an intermediate occurrence is blocked', () {
    final statuses = evaluate(blockedKeys: {'2026-09-27_11:00'});

    expect(statuses[0].availability, RecurringHastaAvailability.available);
    expect(statuses[1].availability, RecurringHastaAvailability.blocked);
    expect(statuses[1].problemDate, '2026-09-27');
    expect(statuses[1].problemTime, '11:00');
    expect(statuses[2].availability, RecurringHastaAvailability.blocked);
    expect(statuses[2].problemDate, '2026-09-27');
    expect(statuses[1].message, contains('27/09'));
  });

  test('propagates an intermediate full slot to later options', () {
    final statuses = evaluate(occupancy: {'2026-09-27_11:00': 5});

    expect(statuses[0].availability, RecurringHastaAvailability.available);
    expect(statuses[1].availability, RecurringHastaAvailability.full);
    expect(statuses[1].problemDate, '2026-09-27');
    expect(statuses[2].availability, RecurringHastaAvailability.full);
    expect(statuses[2].problemDate, '2026-09-27');
  });

  test('propagates an intermediate client conflict to later options', () {
    final statuses = evaluate(
      appointments: [
        _appointment(date: '2026-09-27', time: '11:00'),
      ],
    );

    expect(statuses[0].availability, RecurringHastaAvailability.available);
    expect(statuses[1].availability, RecurringHastaAvailability.conflict);
    expect(statuses[1].problemDate, '2026-09-27');
    expect(statuses[2].availability, RecurringHastaAvailability.conflict);
    expect(statuses[2].problemDate, '2026-09-27');
    expect(
      statuses[1].message,
      'Ya tienes una sesión que se solapa el 27/09/2026.',
    );
  });

  test('ignores rejected and cancelled appointments for conflicts', () {
    final statuses = evaluate(
      appointments: [
        _appointment(
          date: '2026-09-27',
          time: '11:00',
          status: AppointmentStatus.rejected,
        ),
        _appointment(
          id: 'cancelled',
          date: '2026-09-27',
          time: '11:00',
          status: AppointmentStatus.cancelled,
        ),
      ],
    );

    expect(
      statuses.every(
        (status) => status.availability == RecurringHastaAvailability.available,
      ),
      isTrue,
    );
  });

  test('invalidates a 60 min session when a later duration block is blocked or full', () {
    final blockedLater = evaluate(blockedKeys: {'2026-09-27_11:30'});
    expect(blockedLater[0].availability, RecurringHastaAvailability.available);
    expect(blockedLater[1].availability, RecurringHastaAvailability.blocked);
    expect(blockedLater[1].problemDate, '2026-09-27');

    final fullLater = evaluate(occupancy: {'2026-09-27_11:45': 5});
    expect(fullLater[0].availability, RecurringHastaAvailability.available);
    expect(fullLater[1].availability, RecurringHastaAvailability.full);
    expect(fullLater[1].problemDate, '2026-09-27');
  });

  test('uses siteConfig.maxCapacity instead of a hardcoded limit', () {
    final underCapacity = evaluate(occupancy: {'2026-09-25_11:00': 4});
    expect(underCapacity[0].availability, RecurringHastaAvailability.available);

    final atCapacity = evaluate(occupancy: {'2026-09-25_11:00': 5});
    expect(atCapacity[0].availability, RecurringHastaAvailability.full);
    expect(atCapacity[1].availability, RecurringHastaAvailability.full);
    expect(atCapacity[1].problemDate, '2026-09-25');
  });

  test('marks a prefix invalid for outsideSchedule and past', () {
    final outside = evaluate(startTime: '19:45');
    expect(outside[0].availability, RecurringHastaAvailability.outsideSchedule);
    expect(outside[2].availability, RecurringHastaAvailability.outsideSchedule);
    expect(outside[2].problemDate, '2026-09-23');

    final past = evaluate(clock: DateTime(2026, 9, 27, 12));
    expect(past[0].availability, RecurringHastaAvailability.past);
    expect(past[0].problemDate, '2026-09-23');
    expect(past[2].availability, RecurringHastaAvailability.past);
    expect(past[2].problemDate, '2026-09-23');
  });

  test('legacy 30 min occupancy keys invalidate 11:15 and 11:45 sessions', () {
    const fineGrained = SiteConfig(
      startHour: 8,
      endHour: 20,
      slotInterval: 15,
      bonoExpirationMonths: 1,
      maintenanceMode: false,
      maxCapacity: 5,
    );
    final blockedLegacyStart = evaluate(
      startTime: '11:15',
      blockedKeys: {'2026-09-27_11:00'},
      config: fineGrained,
    );
    expect(
      blockedLegacyStart[0].availability,
      RecurringHastaAvailability.available,
    );
    expect(
      blockedLegacyStart[1].availability,
      RecurringHastaAvailability.blocked,
    );
    expect(blockedLegacyStart[1].problemDate, '2026-09-27');

    final fullLegacyMid = evaluate(
      startTime: '11:45',
      occupancy: {'2026-09-27_11:30': 5},
      config: fineGrained,
    );
    expect(fullLegacyMid[0].availability, RecurringHastaAvailability.available);
    expect(fullLegacyMid[1].availability, RecurringHastaAvailability.full);
    expect(fullLegacyMid[1].problemDate, '2026-09-27');
  });

  group('sanitizeRecurringEndDateByAvailability', () {
    final statuses = evaluate(blockedKeys: {'2026-09-27_11:00'});

    test('clears an endDate that became blocked after a ready preview', () {
      expect(
        sanitizeRecurringEndDateByAvailability(
          selectedEndDate: '2026-09-29',
          statuses: statuses,
          phase: RecurringHastaAvailabilityPhase.ready,
        ),
        isNull,
      );
      expect(
        sanitizeRecurringEndDateByAvailability(
          selectedEndDate: '2026-09-25',
          statuses: statuses,
          phase: RecurringHastaAvailabilityPhase.ready,
        ),
        '2026-09-25',
      );
    });

    test('does not clear during loading or error', () {
      expect(
        sanitizeRecurringEndDateByAvailability(
          selectedEndDate: '2026-09-29',
          statuses: statuses,
          phase: RecurringHastaAvailabilityPhase.loading,
        ),
        '2026-09-29',
      );
      expect(
        sanitizeRecurringEndDateByAvailability(
          selectedEndDate: '2026-09-29',
          statuses: statuses,
          phase: RecurringHastaAvailabilityPhase.error,
        ),
        '2026-09-29',
      );
    });
  });
}

Appointment _appointment({
  required String date,
  required String time,
  String id = 'appointment-id',
  AppointmentStatus status = AppointmentStatus.pending,
  int durationMinutes = 60,
}) {
  return Appointment(
    id: id,
    userId: 'uid',
    name: 'Cliente',
    email: 'cliente@example.com',
    phone: '+34612345678',
    serviceType: 'Bono Mensual de Entrenamiento',
    durationMinutes: durationMinutes,
    preferredSlots: [TimeSlot(date: date, time: time)],
    reason: '',
    status: status,
    createdAt: '2026-09-01T10:00:00.000Z',
  );
}
